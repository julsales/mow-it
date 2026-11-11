--!strict
-- Land layout, as data (MapService builds it, Area/MapGeometry read it).
--
-- The land is round and grows outward from the home base:
--   * Ring 0: the home base (a wobbly disc).
--   * Ring 1 and Ring 2: rings split into sectors, one sector per area.
--   * Past the last ring: forest and hills to the horizon, so the world
--     feels endless.
-- Ring and sector borders wobble (sine noise), so nothing is a straight
-- grid line. Angles are degrees clockwise from north (-Z); radii in studs.
-- To add an area: add a Zones.luau row, then a row here. No code changes.

export type GateDef = { Angle: number, Radius: number }

export type AreaDef = {
	Ring: number, -- 0 = base disc, 1.. = outer rings
	From: number?, -- sector start angle (rings >= 1)
	To: number?, -- sector end angle
	Gate: GateDef?, -- where its gate sits (on the border with an earlier area)
	Lawns: { Count: number, MinRadius: number, MaxRadius: number },
	Props: { string }, -- Props.Kinds names, placed irregularly
	ShopAt: string?, -- "House": the area's tool shop is the house's front wall (else a stall)
	Trees: number,
	LuckyChance: number, -- chance a regrown cell is Lucky grass
	GoldenChance: number, -- chance it is Golden grass (rarer, worth more)
}

local MapLayout = {
	Seed = 20261111, -- same seed = same map every server
	-- Outer radius of each ring (index = ring number).
	RingRadius = { [0] = 84, [1] = 176, [2] = 276 },
	-- Border wobble: radius and angle noise amplitudes.
	RingWobble = 6, -- studs
	SectorWobble = 5, -- degrees
	GateWidth = 14,
	FencePostSpacing = 8,
	WallHeight = 16, -- invisible wall above the fence (no jumping over)
	ForestOuterRadius = 450,
	ForestTrees = 170,
	Hills = 12,
	PathWidth = 6,
	LawnMargin = 8, -- studs kept clear between lawns and borders/paths

	Areas = {
		front_yard = {
			Ring = 0,
			Lawns = { Count = 6, MinRadius = 10, MaxRadius = 17 },
			Props = { "Shed", "Planters" }, -- the House is placed first (ShopAt)
			ShopAt = "House",
			Trees = 6,
			LuckyChance = 0.02,
			GoldenChance = 0.003,
		},
		backyard = {
			Ring = 1,
			From = -60,
			To = 60,
			Gate = { Angle = 8, Radius = 84 },
			Lawns = { Count = 7, MinRadius = 12, MaxRadius = 20 },
			Props = { "Pond", "Planters", "Shed" },
			Trees = 12,
			LuckyChance = 0.025,
			GoldenChance = 0.004,
		},
		sunny_farm = {
			Ring = 1,
			From = 60,
			To = 180,
			Gate = { Angle = 60, Radius = 130 },
			Lawns = { Count = 7, MinRadius = 13, MaxRadius = 22 },
			Props = { "Barn", "Silo", "Hay" },
			Trees = 10,
			LuckyChance = 0.025,
			GoldenChance = 0.004,
		},
		big_ranch = {
			Ring = 1,
			From = 180,
			To = 300,
			Gate = { Angle = 180, Radius = 126 },
			Lawns = { Count = 7, MinRadius = 14, MaxRadius = 24 },
			Props = { "RanchHouse", "WaterTower", "Hay" },
			Trees = 12,
			LuckyChance = 0.03,
			GoldenChance = 0.005,
		},
		golf_estate = {
			Ring = 2,
			From = -90,
			To = 90,
			Gate = { Angle = 24, Radius = 176 },
			Lawns = { Count = 9, MinRadius = 15, MaxRadius = 26 },
			Props = { "Mansion", "PuttingGreen", "Bunker", "Bunker" },
			Trees = 16,
			LuckyChance = 0.03,
			GoldenChance = 0.006,
		},
		mega_fields = {
			Ring = 2,
			From = 90,
			To = 270,
			Gate = { Angle = 90, Radius = 226 },
			Lawns = { Count = 9, MinRadius = 16, MaxRadius = 28 },
			Props = { "Hangar", "TallSilo", "TallSilo", "Turbine", "Turbine" },
			Trees = 14,
			LuckyChance = 0.035,
			GoldenChance = 0.008,
		},
	} :: { [string]: AreaDef },
}

return MapLayout
