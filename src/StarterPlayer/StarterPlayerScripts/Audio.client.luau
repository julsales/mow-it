--!strict
-- Everything the player hears, wired to the game (SoundManager plays it,
-- Config/Sounds says what):
--   * Feedback one-shots from the server's CutFeedback / SellFeedback /
--     BuyFeedback / LevelUp remotes (2D, only this player hears them).
--   * Tool loops (3D, everyone hears them) on every held tool on any
--     character: engines idle and rev with speed, reel mowers rattle only
--     while moving, a grass-cutting layer fades in while mowing.
--   * Music + ambience for the island the player stands on.
--   * A click on every button in the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared.Config.Sounds)
local Tools = require(Shared.Config.Tools)
local Zones = require(Shared.Config.Zones)
local MapLayout = require(Shared.Config.MapLayout)
local GrassBag = require(Shared.GrassBag)
local ToolModels = require(Shared.ToolModels)

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local SoundManager = require(script.Parent:WaitForChild("SoundManager"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- The tool model the local character holds, and its sound profile.
local function localTool(): (Model?, Sounds.ToolSoundDef?)
	local character = player.Character
	local model = character and character:FindFirstChild("ToolModel") :: Model?
	if not model then
		return nil, nil
	end
	return model, Sounds.Tools[(model:GetAttribute("Kind") :: string?) or ""]
end

-- Feedback ------------------------------------------------------------------

local lastCutAt: { [Model]: number } = {} -- tool model -> when it last cut grass (drives the Cut layer)

local function fillRatio(): number
	local profile = ClientState.Get()
	return if profile then GrassBag.FillRatio(profile) else 0
end

(remotes:WaitForChild("CutFeedback") :: RemoteEvent).OnClientEvent:Connect(function(stored: number, full: boolean, hit: number?)
	local model, tool = localTool()
	if hit == nil then
		if full then
			SoundManager.Play("Full") -- refused: bag already full
		end
		return
	end
	if hit == 0 then
		if tool and tool.Miss then
			SoundManager.Play(tool.Miss)
		end
		return
	end
	if model then
		lastCutAt[model] = os.clock()
	end
	if tool and tool.CutHit then
		SoundManager.Play(tool.CutHit)
	end
	if stored > 0 then
		-- The server pushes the new profile just before this event.
		SoundManager.Play("Collect", { Pitch = 0.85 + 0.7 * fillRatio() })
	end
	if full then
		SoundManager.Play("Full")
	end
end);

(remotes:WaitForChild("SellFeedback") :: RemoteEvent).OnClientEvent:Connect(function(earned: number)
	SoundManager.Play("Register")
	-- A little cascade of coins: more coins for bigger sales (1 to 6).
	local count = math.clamp(math.floor(math.log10(math.max(earned, 1))) + 1, 1, 6)
	for i = 1, count do
		SoundManager.Play("Coin", { Delay = 0.08 * i, Pitch = 1 + 0.06 * i })
	end
end);

(remotes:WaitForChild("BuyFeedback") :: RemoteEvent).OnClientEvent:Connect(function(kind: string?)
	if kind == "Zone" then
		SoundManager.Play("Unlock")
		SoundManager.Play("Gate")
	else
		SoundManager.Play("Buy")
		SoundManager.Play("Coin", { Pitch = 0.9 })
	end
end);

(remotes:WaitForChild("LevelUp") :: RemoteEvent).OnClientEvent:Connect(function()
	SoundManager.Play("LevelUp")
end)

-- Tool loops ---------------------------------------------------------------------

type Rig = {
	Root: BasePart,
	Def: Sounds.ToolSoundDef,
	PitchScale: number,
	Engine: SoundManager.Loop?,
	Rolling: SoundManager.Loop?,
	Cut: SoundManager.Loop?,
	Speed: number, -- smoothed 0..1.5
	CutLevel: number, -- smoothed 0..1
}
local rigs: { [Model]: Rig } = {}

local FULL_SPEED = 16 -- studs/s that counts as full throttle (default walk speed)

-- Bigger machines of the same kind sound a bit deeper: tools later in the
-- ladder get up to 12% lower pitch than the first tool of their kind.
local function pitchFor(toolId: string?, kind: string): number
	local first, last, here = math.huge, 0, 0
	for i, def in Tools.List do
		if ToolModels.KindOf(def.Id) == kind then
			first = math.min(first, i)
			last = math.max(last, i)
			if def.Id == toolId then
				here = i
			end
		end
	end
	if here == 0 or last <= first then
		return 1
	end
	return 1 - 0.12 * (here - first) / (last - first)
end

local function removeRig(model: Model)
	local rig = rigs[model]
	if not rig then
		return
	end
	for _, loop in { rig.Engine, rig.Rolling, rig.Cut } do
		if loop then
			loop:Destroy()
		end
	end
	rigs[model] = nil
	lastCutAt[model] = nil
end

local function addRig(model: Model)
	if rigs[model] then
		return
	end
	local kind = (model:GetAttribute("Kind") :: string?) or ""
	local def = Sounds.Tools[kind]
	if not def or not (def.Engine or def.Rolling or def.Cut) then
		return
	end
	local character = model.Parent
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local host = (model:FindFirstChild("Engine", true) or model.PrimaryPart or root) :: BasePart?
	if not root or not host or not host:IsA("BasePart") then
		return
	end
	local rig: Rig = {
		Root = root,
		Def = def,
		PitchScale = pitchFor(model:GetAttribute("ToolId") :: string?, kind),
		Engine = if def.Engine then SoundManager.Loop(def.Engine, host) else nil,
		Rolling = if def.Rolling then SoundManager.Loop(def.Rolling, host, "Engines", 60) else nil,
		Cut = if def.Cut then SoundManager.Loop(def.Cut, host) else nil,
		Speed = 0,
		CutLevel = 0,
	}
	rigs[model] = rig
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			removeRig(model)
		end
	end)
end

local function watchCharacter(character: Model)
	local existing = character:FindFirstChild("ToolModel")
	if existing and existing:IsA("Model") then
		addRig(existing)
	end
	character.ChildAdded:Connect(function(child)
		if child.Name == "ToolModel" and child:IsA("Model") then
			-- Attributes are set before parenting on the server; give
			-- replication a frame to bring the descendants along.
			task.defer(addRig, child)
		end
	end)
end

local function watchPlayer(other: Player)
	other.CharacterAdded:Connect(watchCharacter)
	if other.Character then
		watchCharacter(other.Character)
	end
end
Players.PlayerAdded:Connect(watchPlayer)
for _, other in Players:GetPlayers() do
	watchPlayer(other)
end

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	local blend = math.min(dt * 8, 1)
	for model, rig in rigs do
		local v = rig.Root.AssemblyLinearVelocity
		local speed = math.clamp(Vector3.new(v.X, 0, v.Z).Magnitude / FULL_SPEED, 0, 1.5)
		rig.Speed += (speed - rig.Speed) * blend
		-- Other players' cuts aren't sent to us: treat "moving" as cutting
		-- for them; for us, use the real cut feedback.
		local cutting = if model.Parent == player.Character
			then now - (lastCutAt[model] or -math.huge) < 0.6
			else speed > 0.3
		rig.CutLevel += ((if cutting then 1 else 0) - rig.CutLevel) * math.min(dt * 4, 1)
		local def = rig.Def
		local rev = 1 + (def.RevPitch or 0) * math.min(rig.Speed, 1.2)
		if rig.Engine then
			local idle = def.IdleLevel or 0.6
			local level = idle + (1 - idle) * math.max(math.min(rig.Speed, 1), rig.CutLevel * 0.6)
			rig.Engine:Set(level, rig.PitchScale * rev * (1 - 0.04 * rig.CutLevel)) -- bogs down a touch under load
		end
		if rig.Rolling then
			rig.Rolling:Set(math.min(rig.Speed, 1), rig.PitchScale * (0.8 + 0.3 * math.min(rig.Speed, 1.2)))
		end
		if rig.Cut then
			rig.Cut:Set(rig.CutLevel * (0.4 + 0.6 * math.min(rig.Speed, 1)), rig.PitchScale)
		end
	end
end)

-- Music per island ---------------------------------------------------------

-- Island centres come from the baked map (Workspace/Zones/<id> BakedPivot),
-- radii from MapLayout. You're "on" an island inside its radius plus the
-- beach; on a bridge or in the water the current music keeps playing.
local function zoneAt(position: Vector3): string?
	local folder = workspace:FindFirstChild("Zones")
	if not folder then
		return nil
	end
	local best, bestRatio = nil, math.huge
	for _, zone in Zones.List do
		local island = folder:FindFirstChild(zone.Id)
		local area = (MapLayout.Areas :: any)[zone.Id]
		if island and area then
			local pivot = island:GetAttribute("BakedPivot")
			local centre = if typeof(pivot) == "CFrame" then pivot.Position else (island :: Model):GetPivot().Position
			local flat = Vector3.new(position.X - centre.X, 0, position.Z - centre.Z).Magnitude
			local ratio = flat / (area.Radius + MapLayout.Beach)
			if ratio < 1 and ratio < bestRatio then
				best, bestRatio = zone.Id, ratio
			end
		end
	end
	return best
end

SoundManager.SetZone(Zones.List[1].Id) -- you spawn on the home island
task.spawn(function()
	while true do
		task.wait(1)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local zone = root and zoneAt(root.Position)
		if zone then
			SoundManager.SetZone(zone)
		end
	end
end)

-- UI clicks -------------------------------------------------------------------

-- Every GuiButton in the HUD clicks when pressed; set the attribute
-- NoClickSound = true on a button to keep it silent.
local hooked: { [GuiButton]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function hook(object: Instance)
	if object:IsA("GuiButton") and not hooked[object] then
		hooked[object] = true
		object.Activated:Connect(function()
			if object:GetAttribute("NoClickSound") ~= true then
				SoundManager.Play("Click")
			end
		end)
	end
end
local playerGui = player:WaitForChild("PlayerGui")
playerGui.DescendantAdded:Connect(hook)
for _, object in playerGui:GetDescendants() do
	hook(object)
end
