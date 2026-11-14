--!strict
-- Every sound and music track in the game, as data. SoundManager (client)
-- plays them; nothing else should hold a sound id.
--
-- Sources (all free on the Creator Store, usable in any experience):
--   * Pro Sound Effects and APM Music: Roblox's licensed libraries
--     (creators "ProSoundEffects" / "APMOfficial").
--   * Roblox: the official UI sound pack ("Roblox_UI_*").
--   * Daily Sounds (creator "DailySoundsFX"): sounds they synthesized
--     themselves, published free for games.
--   * NordicRider / TunikaTante / SpaceODY: their own recordings of real
--     mowers and a tractor, published free.
-- Every id is logged with its name in docs/ASSETS.md > Audio.
--
-- Volumes were levelled by measuring each file's loudness (AudioAnalyzer
-- RMS) so that one group volume moves a whole family evenly:
-- music ~0.04 RMS, ambience ~0.012, one-shots 0.04-0.08.

export type SoundDef = {
	Ids: { number }, -- several ids = a random one each play (never the same twice in a row)
	Volume: number,
	Pitch: number?, -- PlaybackSpeed, default 1
	PitchJitter: number?, -- random +/- added to Pitch each play, so repeats don't sound robotic
	Start: number?, -- seconds to skip at the start (silence / handling noise)
	Length: number?, -- stop after this many seconds (from Start)
	Group: string?, -- SoundGroup: SFX (default), UI, Stinger
	Cooldown: number?, -- minimum seconds between two plays of this sound
	MaxVoices: number?, -- at most this many copies at once (default 4)
}

-- A looping layer. LoopStart/LoopEnd pick the steady part of a recording
-- (measured: start-up and shut-down are outside it).
export type LoopDef = {
	Id: number,
	Volume: number, -- at full intensity
	Pitch: number?,
	LoopStart: number?,
	LoopEnd: number?,
}

-- How a tool kind (ToolModels.Kinds) sounds while it is held.
--   Engine: always running while equipped, revs with speed.
--   Rolling: only heard while moving (reel mowers have no motor).
--   Cut: extra layer that fades in while grass is being cut.
--   CutHit / Miss: one-shots for hand tools on each swing.
export type ToolSoundDef = {
	Engine: LoopDef?,
	Rolling: LoopDef?,
	Cut: LoopDef?,
	CutHit: string?,
	Miss: string?,
	IdleLevel: number?, -- engine volume when standing still (0..1 of Volume)
	RevPitch: number?, -- extra pitch at full speed (0.3 = +30%)
}

export type TrackDef = { Id: number, Volume: number, Name: string }

local Sounds = {}

Sounds.Effects = {
	-- Hand tools -----------------------------------------------------------
	-- Scissors / shears snipping grass (Pro Sound Effects "Scissors Various
	-- Cuts" + "Hedge Trimmer Scissors Snips").
	Snip = { Ids = { 9118831072, 9118830476, 9114795025, 9114794521 }, Volume = 0.5, Pitch = 1.05, PitchJitter = 0.08, MaxVoices = 3 },
	-- Nail clipper: the same snips, small and high.
	Clip = { Ids = { 9118831072, 9118830476 }, Volume = 0.35, Pitch = 1.45, PitchJitter = 0.08, MaxVoices = 3 },
	-- Sickle / grass whip: a swish through dry fronds (PSE "Dried Palm Fronds Swishing By").
	Slash = { Ids = { 9120957949 }, Volume = 0.6, Pitch = 1.15, PitchJitter = 0.1, Start = 0.25, Length = 0.9, MaxVoices = 3 },
	-- Any hand tool swinging at nothing (Roblox UI whooshes).
	Swish = { Ids = { 15674975792, 15675024286, 15675028888, 15675012262 }, Volume = 0.22, Pitch = 1.1, PitchJitter = 0.1, Cooldown = 0.15 },

	-- Mowing loop feedback ---------------------------------------------------
	-- Grass going into the bag; pitch rises as the bag fills (Daily Sounds "Cartoon Pop").
	Collect = { Ids = { 106984966606682 }, Volume = 0.12, Pitch = 1, Cooldown = 0.12, MaxVoices = 2 },
	-- Bag full (Daily Sounds "Error Buzz").
	Full = { Ids = { 91501650514390 }, Volume = 0.14, Pitch = 0.9, Cooldown = 1.2 },
	-- Coins landing (Daily Sounds "Coin Pickup" / "Retro Coin Collect"); played as a little cascade on sell.
	Coin = { Ids = { 130378474223829, 138309872562566 }, Volume = 0.22, PitchJitter = 0.03, MaxVoices = 6 },
	-- Cash drawer under the coins when selling (PSE "Cash Register 3").
	Register = { Ids = { 9113728198 }, Volume = 0.35, Start = 0.1, Length = 1.6, Cooldown = 0.5 },

	-- Progress stingers (APM Music); the music ducks under them -------------
	-- Bought a tool / bag / buff: "The Plinky Plonk Picnic (Sting 2)".
	Buy = { Ids = { 1841411953 }, Volume = 0.6, Group = "Stinger", Cooldown = 0.4 },
	-- Unlocked an island: "Rural Rapture (sting)".
	Unlock = { Ids = { 1841853310 }, Volume = 0.42, Group = "Stinger", Cooldown = 1 },
	-- The gate swinging open under the unlock sting (PSE "Door Short Squeak").
	Gate = { Ids = { 9114153097 }, Volume = 0.3, Pitch = 0.85, Start = 0.7, Cooldown = 1 },
	-- Company Level up: "Daily Affirmation (Mnemonic 2)", bright ukulele folk.
	LevelUp = { Ids = { 9048750245 }, Volume = 0.5, Group = "Stinger", Cooldown = 1 },

	-- Interface ----------------------------------------------------------------
	-- Every button press (Roblox "UI Bright Click").
	Click = { Ids = { 15675059323 }, Volume = 0.3, PitchJitter = 0.04, Group = "UI", Cooldown = 0.05, MaxVoices = 2 },
} :: { [string]: SoundDef }

-- Tool kinds come from Shared/ToolModels.luau (Kinds).
local MOWER_CUT: LoopDef = { Id = 1688282813, Volume = 0.2 } -- SpaceODY "Lawn Mower": a mower cutting grass

Sounds.Tools = {
	clipper = { CutHit = "Clip", Miss = "Swish" },
	scissors = { CutHit = "Snip", Miss = "Swish" },
	sickle = { CutHit = "Slash", Miss = "Swish" },
	-- PSE "Grass Trimmer 2" (sharp motor buzz), only its running part.
	trimmer = {
		Engine = { Id = 9114657257, Volume = 0.32, Pitch = 1, LoopStart = 1.2, LoopEnd = 7.9 },
		IdleLevel = 0.45,
		RevPitch = 0.12,
	},
	-- PSE "Lawn Mower Old Push Style 7": the ratchety rattle of a reel mower.
	reel = {
		Rolling = { Id = 9116245626, Volume = 0.42, Pitch = 1, LoopStart = 3.3, LoopEnd = 9.3 },
		RevPitch = 0.2,
	},
	-- PSE "Lawn Mower Motor 1": a gas push mower, steady run only.
	push = {
		Engine = { Id = 9116244745, Volume = 0.3, Pitch = 1, LoopStart = 3, LoopEnd = 16 },
		Cut = MOWER_CUT,
		IdleLevel = 0.6,
		RevPitch = 0.25,
	},
	-- NordicRider "Lawn mower Idle (Loop)": a real riding mower, made to loop.
	rider = {
		Engine = { Id = 4946047659, Volume = 0.45, Pitch = 1 },
		Cut = { Id = MOWER_CUT.Id, Volume = 0.18, Pitch = 0.88 },
		IdleLevel = 0.65,
		RevPitch = 0.3,
	},
	-- TunikaTante "Tractor Engine JD loop idle": tractors and harvesters.
	tractor = {
		Engine = { Id = 5306143177, Volume = 0.38, Pitch = 1 },
		Cut = { Id = MOWER_CUT.Id, Volume = 0.16, Pitch = 0.72 },
		IdleLevel = 0.7,
		RevPitch = 0.3,
	},
} :: { [string]: ToolSoundDef }

-- Background music: calm acoustic farm tunes, one theme per island.
-- After a track ends the next one starts (never the same twice in a row):
-- the island's own theme first, then the others.
Sounds.Music = {
	Tracks = {
		lakefront = { Id = 9038622066, Volume = 0.38, Name = "Lakefront Days (Ukulele Underscore)" },
		charming = { Id = 1839578771, Volume = 0.19, Name = "Charming View (Ukulele)" },
		happy_daze = { Id = 1839993539, Volume = 0.31, Name = "Happy Daze (b)" },
		rural = { Id = 1841849270, Volume = 0.23, Name = "Rural Rapture (b)" },
		park = { Id = 1846205663, Volume = 0.36, Name = "A Walk In The Park (B)" },
		sail_boat = { Id = 1840007459, Volume = 0.37, Name = "Sail Boat (c)" },
	} :: { [string]: TrackDef },
	-- Zone id -> its theme, then the rotation.
	Zones = {
		front_yard = { "lakefront", "charming", "happy_daze" },
		backyard = { "charming", "lakefront", "park" },
		sunny_farm = { "happy_daze", "rural", "charming" },
		big_ranch = { "rural", "happy_daze", "sail_boat" },
		golf_estate = { "park", "lakefront", "sail_boat" },
		mega_fields = { "sail_boat", "rural", "happy_daze" },
	} :: { [string]: { string } },
	Fade = 2.5, -- crossfade seconds when the island changes
	Gap = 6, -- seconds of quiet between two tracks
	Duck = 0.35, -- music level while a stinger plays
}

-- Outdoor ambience bed under the music, per island (Pro Sound Effects loops).
Sounds.Ambience = {
	Beds = {
		suburb = { Id = 9112835068, Volume = 3.6, Name = "Neighborhood Birds 2" },
		summer = { Id = 9112749076, Volume = 3, Name = "Birds Park 2 (summer day, insects)" },
		fields = { Id = 9112777821, Volume = 2, Name = "Farmland Presence 2 (crickets, wind in grass)" },
	} :: { [string]: TrackDef },
	Zones = {
		front_yard = "suburb",
		backyard = "suburb",
		sunny_farm = "summer",
		big_ranch = "summer",
		golf_estate = "summer",
		mega_fields = "fields",
	} :: { [string]: string },
}

-- Starting level of each mixer group (SoundService/<name>).
Sounds.Groups = {
	Music = 1,
	Ambience = 1,
	SFX = 1,
	Stinger = 1,
	Engines = 1,
	UI = 1,
}

return Sounds
