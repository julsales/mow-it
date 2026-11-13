--!strict
-- Land layout, as data (MapService builds it, Map/MapGeometry reads it).
--
-- The land is a chain of islands in open water, one island per area, in
-- Zones.luau order: a small, cosy house island first, then every island
-- clearly bigger than the one before (`Radius`).
-- Each island sits `Gap` studs of water past the previous one, in the
-- direction `Heading` (degrees clockwise from north, -Z), so the chain
-- wanders instead of running straight. A wooden bridge joins each island
-- to the next; the area's gate stands on that bridge, so there are no
-- fences on land at all and the next island is always in sight across the
-- water. Coastlines are organic (wobbly radius, beaches, rock cliffs), big
-- lawns cover most of every island, and water runs to the horizon
-- (invisible walls just offshore stop swimming).
--
-- To add an area: add a Zones.luau row, then a row here. No code changes.
-- Distances are in studs.

export type AreaDef = {
	Radius: number, -- average island radius (the coast wobbles around it)
	Heading: number, -- direction from the previous island (ignored on the first)
	Gap: number, -- water between the previous island's coast and this one's
	Cliffs: number, -- 0..1, how much of the coast is rock cliff instead of beach
	Lawns: {
		Rim: number, -- band inside the coast kept for beach, trees and hills
		Holes: number, -- small organic clearings inside the fields
	},
	Props: { string }, -- Props.Kinds names, grouped in one cluster (a farmyard), the first is its center
	ShopAt: string?, -- "House": the player's base (the cabin) stands here, where you spawn
	Trees: number, -- trees along the island's rim, in clusters
	Dock: boolean?, -- a little dock with a moored rowboat on the coast
	Patches: { [string]: number }, -- chance a regrown cell starts a patch of that grass (GrassTypes)
}

local MapLayout = {
	Seed = 20261113, -- same seed = same map every server

	Beach = 18, -- sand band from the grass down into the water
	CliffHeight = 7, -- how high rock cliffs rise above the lawns
	PathWidth = 8, -- dirt path across each island, bridge to bridge
	Bridge = { Width = 12, RailHeight = 3 },
	GateWidth = 12, -- the gate fills the bridge between its rails
	WallHeight = 16, -- the gate's height
	ShoreWallOffset = 8, -- invisible walls this far out in the water
	ShoreWallHeight = 40,
	WaterDepth = 18,
	SeaMargin = 400, -- terrain water past the islands on every side
	FarSea = 30000, -- then flat water plates this far out, to the horizon
	FarSeaOverlap = 200, -- plates start this far inside the terrain water's edge
	FarSeaColor = Color3.fromRGB(98, 226, 232),
	Islets = 16, -- small wooded islets out in the water
	SeaRocks = 40,
	FarIsland = { Distance = 360, Radius = 90 }, -- past the last island, in the haze
	DockLength = 30, -- studs out from the coast (Dock = true islands)

	-- What stands where a bridge arrives on an island (`Forward` studs inland
	-- from the bridge, `Side` studs to the right (+) or left (-) of the path).
	Stations = {
		Sell = { Forward = 18, Side = 13 },
		-- The farmer's tool stand: `Angle` degrees around the coast from the
		-- arrival (alternating sides), `Inland` studs in from the coast.
		Farmer = { Angle = 48, Inland = 30 },
		-- Kept free for a future quick-travel pad (not built yet).
		Travel = { Forward = 12, Side = -11, Radius = 6 },
	},

	Areas = {
		front_yard = {
			Radius = 66,
			Heading = 0,
			Gap = 0,
			Cliffs = 0.15,
			Lawns = { Rim = 22, Holes = 0 },
			Props = { "Planters", "Mailbox" }, -- the house is placed first (ShopAt)
			ShopAt = "House",
			Dock = true,
			Trees = 16,
			Patches = { lucky = 0.002, golden = 0.0006, next = 0.0024 },
		},
		backyard = {
			Radius = 92,
			Heading = -28,
			Gap = 56,
			Cliffs = 0.2,
			Lawns = { Rim = 22, Holes = 2 },
			Props = { "Pond", "Planters", "Shed" },
			Trees = 30,
			Patches = { lucky = 0.0025, golden = 0.0008, next = 0.0024 },
		},
		sunny_farm = {
			Radius = 114,
			Heading = 32,
			Gap = 60,
			Cliffs = 0.25,
			Lawns = { Rim = 22, Holes = 2 },
			Props = { "Barn", "Silo", "Hay" },
			Trees = 36,
			Patches = { lucky = 0.0025, golden = 0.0008, next = 0.0021 },
		},
		big_ranch = {
			Radius = 136,
			Heading = -12,
			Gap = 64,
			Cliffs = 0.35,
			Lawns = { Rim = 22, Holes = 3 },
			Props = { "RanchHouse", "WaterTower", "Hay" },
			Trees = 42,
			Patches = { lucky = 0.003, golden = 0.001, next = 0.0018 },
		},
		golf_estate = {
			Radius = 158,
			Heading = 38,
			Gap = 68,
			Cliffs = 0.2,
			Lawns = { Rim = 22, Holes = 3 },
			Props = { "Mansion", "PuttingGreen", "Bunker", "Bunker" },
			Trees = 48,
			Patches = { lucky = 0.003, golden = 0.0012, next = 0.0018 },
		},
		mega_fields = {
			Radius = 178,
			Heading = -20,
			Gap = 72,
			Cliffs = 0.3,
			Lawns = { Rim = 22, Holes = 3 },
			Props = { "Hangar", "TallSilo", "TallSilo", "Turbine", "Turbine" },
			Trees = 54,
			Patches = { lucky = 0.0035, golden = 0.0015 },
		},
	} :: { [string]: AreaDef },
}

return MapLayout
