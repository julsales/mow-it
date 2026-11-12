--!strict
-- Mowing feel, client side: sounds and auto-mow.
--   * Local feedback sounds (2D, only this player hears them) from the
--     server's CutFeedback / SellFeedback / BuyFeedback remotes.
--   * Engine loop (3D, everyone hears it) on every motor tool model on any
--     character, pitch and volume rising with that character's speed.
--   * Auto-mow: with a ground tool (mower, rider, tractor) walking is
--     mowing, the client asks to cut every tool cooldown; the server still
--     validates and rate-limits every request.
-- All sound ids live in Shared/Config/Sounds.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared.Config.Sounds)
local Tools = require(Shared.Config.Tools)
local GrassBag = require(Shared.GrassBag)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local cutRequest = remotes:WaitForChild("CutRequest") :: RemoteEvent

local ClientState = require(script.Parent:WaitForChild("ClientState"))

-- 2D one-shots -------------------------------------------------------------------

-- SoundGroups so effects and engines can be mixed / muted as a whole later
-- (roblox-audio: route classic Sounds through groups).
local function group(name: string, volume: number): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Volume = volume
	g.Parent = SoundService
	return g
end
local sfxGroup = group("SFX", 1)
local engineGroup = group("Engines", 0.8)

local function newSound(name: string): Sound
	local def = Sounds[name]
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundGroup = sfxGroup
	sound.SoundId = def.Id
	sound.Volume = def.Volume
	local jitter = def.PitchJitter or 0
	sound.PlaybackSpeed = def.Pitch + (math.random() * 2 - 1) * jitter
	return sound
end

local function play2D(name: string, pitchScale: number?)
	local sound = newSound(name)
	sound.PlaybackSpeed *= pitchScale or 1
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(6, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- The tool the local character is holding, from its model's attributes
-- (works even before the first profile push reaches this script).
local function localTool(): (Model?, boolean)
	local character = player.Character
	local model = character and character:FindFirstChild("ToolModel") :: Model?
	return model, model ~= nil and model:GetAttribute("Ground") == true
end

local function fillRatio(): number
	local profile = ClientState.Get()
	if not profile then
		return 0
	end
	return GrassBag.FillRatio(profile)
end

local lastFullAt = 0
local function playFull()
	local now = os.clock()
	if now - lastFullAt > 1.2 then
		lastFullAt = now
		play2D("Full")
	end
end

(remotes:WaitForChild("CutFeedback") :: RemoteEvent).OnClientEvent:Connect(function(stored: number, full: boolean, hit: number?)
	local _, ground = localTool()
	if hit == nil then
		-- Refused before cutting: storage already full.
		if full then
			playFull()
		end
		return
	end
	if hit == 0 then
		if not ground then
			play2D("Swish") -- swung at nothing (mowers stay quiet: the engine is enough)
		end
		return
	end
	play2D(if ground then "MowCut" else "Snip")
	if stored > 0 then
		-- The server pushes the new profile just before this event.
		local fill = fillRatio()
		play2D("Collect", 0.85 + 0.6 * fill)
	end
	if full then
		playFull()
	end
end);

(remotes:WaitForChild("SellFeedback") :: RemoteEvent).OnClientEvent:Connect(function(_earned: number)
	play2D("Sell")
end);

(remotes:WaitForChild("BuyFeedback") :: RemoteEvent).OnClientEvent:Connect(function()
	play2D("Buy")
end);

(remotes:WaitForChild("LevelUp") :: RemoteEvent).OnClientEvent:Connect(function()
	play2D("LevelUp")
end)

-- Engine loops (3D) ------------------------------------------------------------------

type Engine = { Sound: Sound, Root: BasePart }
local engines: { [Model]: Engine } = {}

local ENGINE = Sounds.Engine
local FULL_SPEED = 16 -- studs/s that counts as "full throttle" (default walk speed)

local function addEngine(model: Model)
	if engines[model] or model:GetAttribute("Engine") ~= true then
		return
	end
	local character = model.Parent
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local host = (model:FindFirstChild("Engine", true) or model.PrimaryPart) :: BasePart?
	if not hrp or not host then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "EngineLoop"
	sound.SoundGroup = engineGroup
	sound.SoundId = ENGINE.Id
	sound.Looped = true
	sound.Volume = ENGINE.Volume * 0.6
	sound.PlaybackSpeed = ENGINE.Pitch
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 90
	sound.Parent = host
	sound:Play()
	engines[model] = { Sound = sound, Root = hrp }
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil or not model:IsDescendantOf(workspace) then
			local engine = engines[model]
			if engine then
				engine.Sound:Destroy()
				engines[model] = nil
			end
		end
	end)
end

local function watchCharacter(character: Model)
	local existing = character:FindFirstChild("ToolModel")
	if existing and existing:IsA("Model") then
		addEngine(existing)
	end
	character.ChildAdded:Connect(function(child)
		if child.Name == "ToolModel" and child:IsA("Model") then
			-- Attributes are set before parenting on the server, but give
			-- replication a frame to bring the descendants along.
			task.defer(addEngine, child)
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

RunService.Heartbeat:Connect(function()
	for _, engine in engines do
		local v = engine.Root.AssemblyLinearVelocity
		local speed = math.clamp(Vector3.new(v.X, 0, v.Z).Magnitude / FULL_SPEED, 0, 1.5)
		local targetPitch = ENGINE.Pitch * (1 + 0.55 * speed)
		local targetVolume = ENGINE.Volume * (0.6 + 0.4 * math.min(speed, 1))
		-- Smooth so the engine revs instead of jumping.
		engine.Sound.PlaybackSpeed += (targetPitch - engine.Sound.PlaybackSpeed) * 0.15
		engine.Sound.Volume += (targetVolume - engine.Sound.Volume) * 0.15
	end
end)

-- Auto-mow --------------------------------------------------------------------------

local nextAutoCut = 0
RunService.Heartbeat:Connect(function()
	local model, ground = localTool()
	if not model or not ground then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.MoveDirection.Magnitude < 0.1 or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	if now < nextAutoCut then
		return
	end
	local tool = Tools.ById[(model:GetAttribute("ToolId") :: string?) or ""]
	local cooldown = tool and tool.Cooldown or 0.4
	nextAutoCut = now + cooldown * 1.05
	cutRequest:FireServer()
end)
