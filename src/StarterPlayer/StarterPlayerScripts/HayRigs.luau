--!strict
-- Moves the animated pieces of a hay yard model (the baler, the silo), on
-- this client only. Pieces carry a "Rig" attribute (from the Blender mesh
-- names "…#Rig"); how each rig moves is data (Config/HayYard Pieces.Rigs):
-- Spin, Shake, Slide, Swing, Loop, optionally mounted on a parent rig.
-- The owner sets one number per rig (speed or 0..1) and calls Step.
--
-- Pieces are anchored: we set their CFrame from the model's pivot, so the
-- model can be dragged anywhere in Studio and still animates in place.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.HayYard)

type Piece = { Part: BasePart, Rest: CFrame, Size: Vector3 }
type Rig = { Def: Config.RigDef, Pivot: Vector3, Pieces: { Piece }, Phase: number, Value: number, Total: CFrame, Last: CFrame?, LastValue: number, Stepped: number }

local HayRigs = {}
HayRigs.__index = HayRigs

export type Player = typeof(setmetatable({} :: { Model: Model, Rigs: { [string]: Rig }, Frame: number, LastPivot: CFrame?, Dirty: boolean, Connection: RBXScriptConnection? }, HayRigs))

function HayRigs.new(model: Model, defs: { [string]: Config.RigDef }): Player
	local self = setmetatable({ Model = model, Rigs = {}, Frame = 0, LastPivot = nil, Dirty = true, Connection = nil }, HayRigs)
	for name, def in defs do
		local pivot = model:GetAttribute("Pivot_" .. name)
		self.Rigs[name] = { Def = def, Pivot = if typeof(pivot) == "Vector3" then pivot else Vector3.zero, Pieces = {}, Phase = 0, Value = 0, Total = CFrame.identity, Last = nil, LastValue = -1, Stepped = -1 }
	end
	-- Streaming / late replication: pick up pieces as they arrive.
	self.Connection = model.DescendantAdded:Connect(function()
		self.Dirty = true
	end)
	return self
end

function HayRigs.Destroy(self: Player)
	if self.Connection then
		self.Connection:Disconnect()
	end
end

-- A piece's place and size at rest, relative to the model. Remembered on
-- the piece the first time we see it (it is still as the server made it).
local function restOf(model: Model, part: BasePart): (CFrame, Vector3)
	local rest, size = part:GetAttribute("Rest"), part:GetAttribute("RestSize")
	if typeof(rest) ~= "CFrame" or typeof(size) ~= "Vector3" then
		rest, size = model:GetPivot():ToObjectSpace(part.CFrame), part.Size
		part:SetAttribute("Rest", rest)
		part:SetAttribute("RestSize", size)
	end
	return rest :: CFrame, size :: Vector3
end

local function scan(self: Player)
	self.Dirty = false
	for _, rig in self.Rigs do
		table.clear(rig.Pieces)
		rig.Last = nil
	end
	for _, d in self.Model:GetDescendants() do
		local name = d:IsA("BasePart") and d:GetAttribute("Rig")
		local rig = if typeof(name) == "string" then self.Rigs[name] else nil
		if rig then
			local rest, size = restOf(self.Model, d :: BasePart)
			table.insert(rig.Pieces, { Part = d :: BasePart, Rest = rest, Size = size })
		end
	end
end

function HayRigs.Set(self: Player, name: string, value: number)
	local rig = self.Rigs[name]
	if rig then
		rig.Value = value
	end
end

local function about(pivot: Vector3, turn: CFrame): CFrame
	return CFrame.new(pivot) * turn * CFrame.new(-pivot)
end

local function own(rig: Rig, dt: number): CFrame
	local def, value = rig.Def, rig.Value
	local axis = def.Axis or Vector3.yAxis
	if def.Kind == "Spin" then
		rig.Phase = (rig.Phase + value * dt) % (2 * math.pi)
		return about(rig.Pivot, CFrame.fromAxisAngle(axis, rig.Phase))
	elseif def.Kind == "Shake" then
		rig.Phase += dt
		local t = rig.Phase
		return CFrame.new(0, value * 0.035 * math.sin(t * 41), 0) * about(rig.Pivot, CFrame.Angles(value * 0.009 * math.sin(t * 33), 0, value * 0.011 * math.sin(t * 27 + 1)))
	elseif def.Kind == "Slide" then
		return CFrame.new(axis * (def.Travel or 1) * value)
	elseif def.Kind == "Swing" then
		return about(rig.Pivot, CFrame.fromAxisAngle(axis, math.rad(def.Angle or 45) * value))
	elseif def.Kind == "Loop" then
		local travel = def.Travel or 1
		rig.Phase = (rig.Phase + value * dt) % travel
		return CFrame.new(axis * rig.Phase)
	end
	return CFrame.identity -- Grow: sized in Step
end

local function resolve(self: Player, rig: Rig, dt: number): CFrame
	if rig.Stepped ~= self.Frame then
		rig.Stepped = self.Frame
		local parent = rig.Def.Parent and self.Rigs[rig.Def.Parent]
		local total = own(rig, dt)
		rig.Total = if parent then resolve(self, parent, dt) * total else total
	end
	return rig.Total
end

function HayRigs.Step(self: Player, dt: number)
	if self.Dirty then
		scan(self)
	end
	self.Frame += 1
	local pivot = self.Model:GetPivot()
	local moved = pivot ~= self.LastPivot
	self.LastPivot = pivot
	for _, rig in self.Rigs do
		local total = resolve(self, rig, dt)
		local grow = rig.Def.Kind == "Grow"
		if moved or total ~= rig.Last or (grow and rig.Value ~= rig.LastValue) then
			rig.Last = total
			rig.LastValue = rig.Value
			for _, piece in rig.Pieces do
				if grow then
					-- shrink toward the rig's pivot; gone when there is nothing left
					local scale = math.clamp(rig.Value, 0, 1)
					local rest = piece.Rest
					piece.Part.Size = piece.Size * math.max(scale, 0.02)
					piece.Part.Transparency = if scale < 0.04 then 1 else 0
					piece.Part.CFrame = pivot * total * (rest.Rotation + rig.Pivot + (rest.Position - rig.Pivot) * scale)
				else
					piece.Part.CFrame = pivot * total * piece.Rest
				end
			end
		end
	end
end

return HayRigs
