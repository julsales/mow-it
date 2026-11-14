--!strict
-- SoundManager: the one place the client makes noise.
--
--   SoundManager.Play(name, options?)      one-shot from Config/Sounds Effects
--   SoundManager.Loop(def, parent, group)  a looping layer you can fade
--   SoundManager.Music / .Ambience         crossfading players per island
--   SoundManager.SetVolume(group, v)       mixer (Music, Ambience, SFX, ...)
--
-- Classic Sound + SoundGroup (roblox-audio): every sound is routed through
-- a group in SoundService so a future settings menu can move a whole family.
-- One-shots are pooled per id (no new Instance per swing), pick a random
-- variant that is never the same twice in a row, jitter their pitch, and
-- respect a per-sound cooldown and voice cap so fast tools can't machine-gun.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Sounds"))

type SoundDef = Sounds.SoundDef
type LoopDef = Sounds.LoopDef
type TrackDef = Sounds.TrackDef

local SoundManager = {}

-- Mixer ---------------------------------------------------------------------

local groups: { [string]: SoundGroup } = {}
local function group(name: string): SoundGroup
	local existing = groups[name]
	if existing then
		return existing
	end
	local g = SoundService:FindFirstChild(name)
	if not (g and g:IsA("SoundGroup")) then
		local created = Instance.new("SoundGroup")
		created.Name = name
		created.Volume = (Sounds.Groups :: any)[name] or 1
		created.Parent = SoundService
		g = created
	end
	groups[name] = g :: SoundGroup
	return g :: SoundGroup
end
for name in Sounds.Groups do
	group(name)
end
SoundManager.Group = group

function SoundManager.SetVolume(name: string, volume: number)
	group(name).Volume = math.clamp(volume, 0, 2)
end

-- One-shots ---------------------------------------------------------------

local folder = Instance.new("Folder")
folder.Name = "OneShots"
folder.Parent = SoundService

local pools: { [string]: { Sound } } = {} -- name -> sounds (playing or idle)
local lastPlayedAt: { [string]: number } = {}
local lastVariant: { [string]: number } = {}

local function pickId(name: string, def: SoundDef): number
	local ids = def.Ids
	if #ids == 1 then
		return ids[1]
	end
	local index = math.random(1, #ids - 1)
	if index >= (lastVariant[name] or 0) then
		index += 1 -- skip the one played last time
	end
	lastVariant[name] = index
	return ids[index]
end

local function voice(name: string, def: SoundDef): Sound?
	local pool = pools[name]
	if not pool then
		pool = {}
		pools[name] = pool
	end
	local oldest: Sound? = nil
	for _, sound in pool do
		if not sound.IsPlaying then
			return sound
		end
		if not oldest or sound.TimePosition > oldest.TimePosition then
			oldest = sound
		end
	end
	if #pool < (def.MaxVoices or 4) then
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundGroup = group(def.Group or "SFX")
		sound.Parent = folder
		table.insert(pool, sound)
		return sound
	end
	return oldest -- steal the voice that has played longest
end

local stingerCount = 0

export type PlayOptions = {
	Pitch: number?, -- multiplies the def's pitch
	Volume: number?, -- multiplies the def's volume
	Delay: number?,
}

local function playNow(name: string, def: SoundDef, options: PlayOptions?)
	local sound = voice(name, def)
	if not sound then
		return
	end
	local pitch = (def.Pitch or 1) + (math.random() * 2 - 1) * (def.PitchJitter or 0)
	sound:Stop()
	sound.SoundId = "rbxassetid://" .. pickId(name, def)
	sound.Volume = def.Volume * (options and options.Volume or 1)
	sound.PlaybackSpeed = pitch * (options and options.Pitch or 1)
	if def.Length then
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(def.Start or 0, (def.Start or 0) + def.Length)
	else
		sound.PlaybackRegionsEnabled = false
		sound.TimePosition = def.Start or 0
	end
	if def.Group == "Stinger" then
		-- One stinger at a time: a new one cuts the previous (buying and
		-- levelling up in the same second would otherwise clash).
		for otherName, pool in pools do
			local other = Sounds.Effects[otherName]
			if otherName ~= name and other and other.Group == "Stinger" then
				for _, s in pool do
					s:Stop()
				end
			end
		end
	end
	sound:Play()
	if def.Group == "Stinger" then
		-- Duck the music under the stinger, bring it back when it ends.
		stingerCount += 1
		SoundManager.Music:Duck(true)
		task.delay(4, function()
			stingerCount -= 1
			if stingerCount <= 0 then
				stingerCount = 0
				SoundManager.Music:Duck(false)
			end
		end)
	end
end

function SoundManager.Play(name: string, options: PlayOptions?)
	local def = Sounds.Effects[name]
	if not def then
		warn("SoundManager: no sound named " .. name)
		return
	end
	local now = os.clock()
	if def.Cooldown and now - (lastPlayedAt[name] or -math.huge) < def.Cooldown then
		return
	end
	lastPlayedAt[name] = now
	local delay = options and options.Delay
	if delay and delay > 0 then
		task.delay(delay, playNow, name, def, options)
	else
		playNow(name, def, options)
	end
end

-- Loops -------------------------------------------------------------------

export type Loop = {
	Sound: Sound,
	Def: LoopDef,
	Set: (self: Loop, level: number, pitchScale: number?) -> (),
	Destroy: (self: Loop) -> (),
}

local LoopClass = {}
LoopClass.__index = LoopClass

-- level 0..1 of the def's volume; smooth it yourself (called every frame).
function LoopClass.Set(self: Loop, level: number, pitchScale: number?)
	self.Sound.Volume = self.Def.Volume * math.max(level, 0)
	self.Sound.PlaybackSpeed = (self.Def.Pitch or 1) * (pitchScale or 1)
end

function LoopClass.Destroy(self: Loop)
	self.Sound:Destroy()
end

-- A looped Sound on `parent` (a part = 3D, heard by whoever is near it).
function SoundManager.Loop(def: LoopDef, parent: Instance, groupName: string?, maxDistance: number?): Loop
	local sound = Instance.new("Sound")
	sound.Name = "Loop"
	sound.SoundId = "rbxassetid://" .. def.Id
	sound.SoundGroup = group(groupName or "Engines")
	sound.Looped = true
	sound.Volume = 0
	sound.PlaybackSpeed = def.Pitch or 1
	if def.LoopStart and def.LoopEnd then
		sound.PlaybackRegionsEnabled = true
		sound.LoopRegion = NumberRange.new(def.LoopStart, def.LoopEnd)
		sound.TimePosition = def.LoopStart + math.random() * (def.LoopEnd - def.LoopStart)
	else
		sound.TimePosition = math.random() * 2 -- two mowers side by side don't phase
	end
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = maxDistance or 90
	sound.Parent = parent
	sound:Play()
	return setmetatable({ Sound = sound, Def = def }, LoopClass) :: any
end

-- Crossfading players (music, ambience) ------------------------------------

export type Player2D = {
	Play: (self: Player2D, track: TrackDef?) -> (),
	Duck: (self: Player2D, on: boolean) -> (),
	Current: TrackDef?,
	Ended: BindableEvent,
}

local function newPlayer(groupName: string, looped: boolean, fade: number): Player2D
	local g = group(groupName)
	local base = g.Volume
	local self = { Current = nil :: TrackDef?, Ended = Instance.new("BindableEvent") }
	local active: Sound? = nil

	local function fadeOut(sound: Sound)
		local tween = TweenService:Create(sound, TweenInfo.new(fade), { Volume = 0 })
		tween.Completed:Once(function()
			sound:Destroy()
		end)
		tween:Play()
	end

	function self.Play(_: any, track: TrackDef?)
		if self.Current == track and active then
			return
		end
		self.Current = track
		if active then
			fadeOut(active)
			active = nil
		end
		if not track then
			return
		end
		local sound = Instance.new("Sound")
		sound.Name = groupName
		sound.SoundId = "rbxassetid://" .. track.Id
		sound.SoundGroup = g
		sound.Looped = looped
		sound.Volume = 0
		sound.Parent = SoundService
		sound:Play()
		TweenService:Create(sound, TweenInfo.new(fade), { Volume = track.Volume }):Play()
		active = sound
		sound.Ended:Connect(function()
			if active == sound then
				active = nil
				sound:Destroy()
				self.Current = nil
				self.Ended:Fire(track)
			end
		end)
	end

	function self.Duck(_: any, on: boolean)
		TweenService:Create(g, TweenInfo.new(if on then 0.25 else 1.2), {
			Volume = if on then base * Sounds.Music.Duck else base,
		}):Play()
	end

	return self :: any
end

SoundManager.Music = newPlayer("Music", false, Sounds.Music.Fade)
SoundManager.Ambience = newPlayer("Ambience", true, 3)

-- Island-aware music rotation: the island's theme, then the others in its
-- list, a short quiet gap between tracks, never the same track twice in a row.
local musicZone: string? = nil
local lastTrack: string? = nil
local rotation = 0

local function nextTrackName(zoneId: string): string?
	local list = Sounds.Music.Zones[zoneId]
	if not list or #list == 0 then
		return nil
	end
	for _ = 1, #list do
		rotation = rotation % #list + 1
		local name = list[rotation]
		if name ~= lastTrack or #list == 1 then
			return name
		end
	end
	return list[1]
end

local function startTrack(name: string?)
	lastTrack = name
	SoundManager.Music:Play(if name then Sounds.Music.Tracks[name] else nil)
end

function SoundManager.SetZone(zoneId: string)
	if zoneId == musicZone then
		return
	end
	musicZone = zoneId
	rotation = 0
	startTrack(nextTrackName(zoneId))
	local bed = Sounds.Ambience.Zones[zoneId]
	SoundManager.Ambience:Play(if bed then Sounds.Ambience.Beds[bed] else nil)
end

SoundManager.Music.Ended.Event:Connect(function()
	local zone = musicZone
	task.delay(Sounds.Music.Gap, function()
		if zone == musicZone and SoundManager.Music.Current == nil and zone then
			startTrack(nextTrackName(zone))
		end
	end)
end)

-- Preload the short sounds heard in the first minute (not the music:
-- it streams, and preloading it slows the join).
task.spawn(function()
	local preload = {}
	for _, name in { "Snip", "Clip", "Swish", "Collect", "Coin", "Click", "Full" } do
		for _, id in Sounds.Effects[name].Ids do
			local s = Instance.new("Sound")
			s.SoundId = "rbxassetid://" .. id
			table.insert(preload, s)
		end
	end
	pcall(function()
		ContentProvider:PreloadAsync(preload)
	end)
	for _, s in preload do
		s:Destroy()
	end
end)

return SoundManager
