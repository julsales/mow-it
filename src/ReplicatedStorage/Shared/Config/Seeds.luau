--!strict
-- Plantable special grass (spec: openspec/specs/seed-plots). GrowSeconds is
-- real time and elapses offline too. YieldMultiplier is vs normal grass.

export type SeedDef = { Id: string, DisplayName: string, Expansion: string, GrowSeconds: number, YieldMultiplier: number }

local Seeds: { SeedDef } = {
	{ Id = "clover_seed", DisplayName = "Clover Patch Seed", Expansion = "front_yard", GrowSeconds = 600, YieldMultiplier = 1.5 },
	{ Id = "dewy_seed", DisplayName = "Dewy Grass Seed", Expansion = "front_yard", GrowSeconds = 900, YieldMultiplier = 2 },
	{ Id = "honey_seed", DisplayName = "Honey Grass Seed", Expansion = "backyard", GrowSeconds = 1800, YieldMultiplier = 3 },
	{ Id = "mint_seed", DisplayName = "Mint Meadow Seed", Expansion = "backyard", GrowSeconds = 2700, YieldMultiplier = 4 },
	{ Id = "wheatgold_seed", DisplayName = "Wheatgold Seed", Expansion = "sunny_farm", GrowSeconds = 5400, YieldMultiplier = 6 },
	{ Id = "sunmelon_seed", DisplayName = "Sunmelon Turf Seed", Expansion = "sunny_farm", GrowSeconds = 8100, YieldMultiplier = 8 },
	{ Id = "prairie_seed", DisplayName = "Prairie King Seed", Expansion = "big_ranch", GrowSeconds = 16200, YieldMultiplier = 12 },
	{ Id = "cactusbloom_seed", DisplayName = "Cactus Bloom Seed", Expansion = "big_ranch", GrowSeconds = 24300, YieldMultiplier = 16 },
	{ Id = "emerald_seed", DisplayName = "Emerald Fairway Seed", Expansion = "golf_estate", GrowSeconds = 48600, YieldMultiplier = 24 },
	{ Id = "diamond_seed", DisplayName = "Diamond Turf Seed", Expansion = "golf_estate", GrowSeconds = 72900, YieldMultiplier = 32 },
	{ Id = "starlight_seed", DisplayName = "Starlight Seed", Expansion = "mega_fields", GrowSeconds = 145800, YieldMultiplier = 48 },
	{ Id = "void_seed", DisplayName = "Void Meadow Seed", Expansion = "mega_fields", GrowSeconds = 218700, YieldMultiplier = 64 },
}

local byId: { [string]: SeedDef } = {}
for _, s in Seeds do byId[s.Id] = s end

return { List = Seeds, ById = byId }
