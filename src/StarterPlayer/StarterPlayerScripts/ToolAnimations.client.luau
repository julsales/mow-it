--!strict
-- Moves the animated pieces of every held tool (any player's), on this
-- client only. Pieces carry a "Rig" attribute (ToolModels, from the Blender
-- mesh names "…#Rig", see Config/ToolArt):
--   Spin*/Reel  roll with the ground speed (wheels, reel-mower blades)
--   Drum        turns all the time (MOWZILLA cutter, combine header reel)
--   JawTop/JawBottom chomp open and shut while the machine drives (MOWZILLA)
--   Rotor*/Head spin fast around their own Y (propellers, trimmer string)
--   Portal      turns slowly around its own Y (VOID portal)
--   Prop/Drill  spin around their own Z (blimp propeller, drill nose)
--   Orbit       circles the player (mini drones, void shards)
--   Buzz        shakes while cutting (hedge trimmer bar, saw chain)
--   SnipL/SnipR/Lever open and close around the model's SnipPivot on each
--               cut (the server stamps SwingAt on the model per cut).
-- Also: pieces tagged "RainbowPiece" (Rainbow finish, held or on display)
-- cycle through the rainbow.
-- Each piece is welded to the model's Root; we only change the weld's C0
-- around the value it was built with.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

type Piece = { Weld: Weld, Base: CFrame }
type Rig = { Name: string, Pieces: { Piece }, Radius: number, Angle: number, Pivot: Vector3, PivotSize: number }
type Entry = { Model: Model, Rigs: { Rig }, Dirty: boolean, Connection: RBXScriptConnection? }

local SNIP_TIME = 0.28 -- seconds for one open-close
local BUZZ_TIME = 0.45

local entries: { [Model]: Entry } = setmetatable({}, { __mode = "k" }) :: any

local function scan(model: Model): Entry
	local byName: { [string]: Rig } = {}
	local rigs: { Rig } = {}
	for _, part in model:GetDescendants() do
		local name = part:IsA("BasePart") and part:GetAttribute("Rig")
		local weld = if typeof(name) == "string" then part:FindFirstChildOfClass("Weld") else nil
		if typeof(name) == "string" and weld then
			local rig = byName[name]
			if not rig then
				rig = { Name = name, Pieces = {}, Radius = 0.1, Angle = 0, Pivot = weld.C0.Position, PivotSize = 0 }
				byName[name] = rig
				table.insert(rigs, rig)
			end
			table.insert(rig.Pieces, { Weld = weld, Base = weld.C0 })
			rig.Radius = math.max(rig.Radius, (part :: BasePart).Size.Y / 2)
			-- Everything in a rig turns around its biggest piece's centre
			-- (the drill cone, the drum, the tyre), so small pieces that sit
			-- off-centre (spikes, spokes) stay attached.
			local size = (part :: BasePart).Size.Magnitude
			if size > rig.PivotSize then
				rig.PivotSize = size
				rig.Pivot = weld.C0.Position
			end
		end
	end
	local entry: Entry = { Model = model, Rigs = rigs, Dirty = false, Connection = nil }
	-- Big models replicate in pieces: rescan when more pieces arrive.
	entry.Connection = model.DescendantAdded:Connect(function()
		entry.Dirty = true
	end)
	return entry
end

local function startsWith(s: string, prefix: string): boolean
	return string.sub(s, 1, #prefix) == prefix
end

local function animate(entry: Entry, hrp: BasePart?, now: number, dt: number)
	local model = entry.Model
	local swingAt = model:GetAttribute("SwingAt")
	local sinceSwing = if typeof(swingAt) == "number" then now - swingAt else math.huge
	local speed = 0
	if hrp then
		speed = hrp.AssemblyLinearVelocity:Dot(hrp.CFrame.LookVector)
	end
	for _, rig in entry.Rigs do
		local name = rig.Name
		local function each(make: (Piece) -> CFrame)
			for _, piece in rig.Pieces do
				piece.Weld.C0 = make(piece)
			end
		end
		if startsWith(name, "Spin") or name == "Reel" then
			-- Rolling forward (-Z): the top of the wheel moves forward.
			rig.Angle -= speed / rig.Radius * dt
			local turn = CFrame.new(rig.Pivot) * CFrame.Angles(rig.Angle, 0, 0) * CFrame.new(-rig.Pivot)
			each(function(p)
				return turn * p.Base
			end)
		elseif name == "JawTop" or name == "JawBottom" then
			-- Chomps faster the faster you drive; shut when standing still.
			local moving = math.clamp(math.abs(speed) / 12, 0, 1)
			rig.Angle += (4 + 8 * moving) * dt
			local open = moving * 0.35 * (0.5 + 0.5 * math.sin(rig.Angle * 2))
			local dy = if name == "JawTop" then open else -open
			each(function(p)
				return p.Base + Vector3.new(0, dy, 0)
			end)
		elseif name == "Drum" then
			rig.Angle -= 7 * dt
			local turn = CFrame.new(rig.Pivot) * CFrame.Angles(rig.Angle, 0, 0) * CFrame.new(-rig.Pivot)
			each(function(p)
				return turn * p.Base
			end)
		elseif startsWith(name, "Rotor") or name == "Head" or name == "Portal" then
			rig.Angle += (if name == "Portal" then 2.5 else 22) * dt
			local turn = CFrame.new(rig.Pivot) * CFrame.Angles(0, rig.Angle, 0) * CFrame.new(-rig.Pivot)
			each(function(p)
				return turn * p.Base
			end)
		elseif name == "Prop" or name == "Drill" then
			rig.Angle += (if name == "Prop" then 14 else 8) * dt
			local turn = CFrame.new(rig.Pivot) * CFrame.Angles(0, 0, rig.Angle) * CFrame.new(-rig.Pivot)
			each(function(p)
				return turn * p.Base
			end)
		elseif name == "Orbit" then
			rig.Angle += 0.9 * dt
			each(function(p)
				return CFrame.Angles(0, rig.Angle, 0) * p.Base
			end)
		elseif name == "Buzz" then
			local x = if sinceSwing < BUZZ_TIME then 0.05 * math.sin(now * 90) else 0
			each(function(p)
				return p.Base + Vector3.new(x, 0, 0)
			end)
		elseif name == "SnipL" or name == "SnipR" or name == "Lever" then
			local pivot = model:GetAttribute("SnipPivot")
			local axis = model:GetAttribute("SnipAxis")
			local maxAngle = model:GetAttribute("SnipAngle")
			if typeof(pivot) == "Vector3" and typeof(axis) == "Vector3" and typeof(maxAngle) == "number" then
				local t = if sinceSwing < SNIP_TIME then sinceSwing / SNIP_TIME else 1
				local angle = math.rad(maxAngle) * math.sin(math.pi * t) * (if name == "SnipR" then -1 else 1)
				local hinge = CFrame.new(pivot) * CFrame.fromAxisAngle(axis, angle) * CFrame.new(-pivot)
				each(function(p)
					return hinge * p.Base
				end)
			end
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	for i, piece in CollectionService:GetTagged("RainbowPiece") do
		if piece:IsA("BasePart") then
			piece.Color = Color3.fromHSV((now * 0.2 + i * 0.07) % 1, 0.7, 1)
		end
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local model = character and character:FindFirstChild("ToolModel")
		if model and model:IsA("Model") then
			local entry = entries[model]
			if not entry or entry.Dirty then
				if entry and entry.Connection then
					entry.Connection:Disconnect()
				end
				entry = scan(model)
				entries[model] = entry
			end
			if #entry.Rigs > 0 then
				animate(entry, (character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?, now, dt)
			end
		end
	end
end)
