--!strict
-- Every sound the mowing loop plays, in one place so swapping a placeholder
-- for a Creator Store sound is a one-line change (docs/ASSETS.md > Audio).
--
-- Defaults use sounds that ship inside every Roblox client
-- ("rbxasset://sounds/..."), so they always play and need no permission.
-- To use a Creator Store sound: Toolbox -> Audio, search, right-click ->
-- Copy Asset ID, then set Id = "rbxassetid://<id>". Log the choice in
-- docs/ASSETS.md.

export type SoundDef = {
	Id: string,
	Volume: number,
	Pitch: number, -- PlaybackSpeed
	PitchJitter: number?, -- random +/- added to Pitch each play, so repeats don't sound robotic
}

local Sounds: { [string]: SoundDef } = {
	-- Hand tools (clippers, scissors, sickle...) on every swing that cuts.
	Snip = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.35, Pitch = 1.9, PitchJitter = 0.15 },
	-- Hand tools swinging at nothing.
	Swish = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.2, Pitch = 1.4, PitchJitter = 0.1 },
	-- Mowers chewing through grass (plays on top of the engine).
	MowCut = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.3, Pitch = 0.8, PitchJitter = 0.1 },
	-- Grass going into storage; pitch rises as storage fills.
	Collect = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.12, Pitch = 1.6 },
	-- Storage full.
	Full = { Id = "rbxasset://sounds/snap.wav", Volume = 0.5, Pitch = 0.6 },
	-- Selling at the pad.
	Sell = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Pitch = 1.0 },
	-- Buying a tool / storage / zone.
	Buy = { Id = "rbxasset://sounds/victory.wav", Volume = 0.4, Pitch = 1.0 },
	-- Engine loop of motor mowers. PLACEHOLDER: a fast click looped at low
	-- pitch reads as a small two-stroke engine. Replace with a real mower
	-- loop: Toolbox -> Audio -> "lawn mower", or upload the CC0 BigSoundBank
	-- #1071 recording picked in the Asset Picker.
	Engine = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.25, Pitch = 0.55 },
}

return Sounds
