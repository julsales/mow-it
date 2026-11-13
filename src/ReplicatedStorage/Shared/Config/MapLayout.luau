--!strict
-- Land layout, as data (MapService builds it, Map/MapGeometry reads it).
--
-- The land is a farm road: one winding dirt road that starts at the house
-- (Front Yard) and runs through every area in Zones.luau order. Each area
-- straddles the road and is a stretch of it (`Length` studs along the road,
-- `HalfWidth` studs to each side), wider than the one before. Lawns are big
-- fields on both sides of the road. Between two areas there is only a fence
-- line across the land with one gate on the road, so the next gate is
-- always ahead and in sight. The land is an island: past the area edges a
-- tree line, a beach and then water to the horizon (shore walls stop
-- swimming); past the last area the road leaves over a closed bridge.
--
-- To add an area: add a Zones.luau row, then a row here (it goes after the
-- previous area on the road). No code changes. Distances are in studs.

export type AreaDef = {
	Length: number, -- how far the area runs along the road
	HalfWidth: number, -- land on each side of the road's center line
	Lawns: {
		Verge: number, -- grass-free strip between the road edge and the lawns
		Rim: number, -- strip at the area edge kept for the tree line
		Holes: number, -- small organic clearings inside the fields
	},
	Props: { string }, -- Props.Kinds names, placed irregularly next to the road
	ShopAt: string?, -- "House": the area's shop is the house at the road start (else a stall)
	Trees: number, -- tree line along the area's sides
	Patches: { [string]: number }, -- chance a regrown cell starts a patch of that grass (GrassTypes)
}

local MapLayout = {
	Seed = 20261113, -- same seed = same map every server

	Road = {
		Width = 12,
		-- Control points (X, Z) of the road's center line, a smooth spline
		-- through them. Starts at the house porch and heads north (-Z) in
		-- gentle S curves; it must be longer than all areas together plus
		-- `EndLand` and `BridgeLength`.
		Points = {
			Vector2.new(0, 0),
			Vector2.new(4, -120),
			Vector2.new(44, -260),
			Vector2.new(84, -430),
			Vector2.new(58, -610),
			Vector2.new(-16, -780),
			Vector2.new(-62, -960),
			Vector2.new(-36, -1140),
			Vector2.new(30, -1310),
			Vector2.new(70, -1490),
			Vector2.new(46, -1670),
			Vector2.new(4, -1840),
			Vector2.new(-30, -1990),
		},
		StartLand = 84, -- land behind the road start (the house stands there)
		EndLand = 40, -- land past the last area before the shore
		BridgeLength = 90, -- the road goes on over the water, closed for now
	},

	Beach = 26, -- sand from the area edge down into the water
	ShoreWallHeight = 40, -- invisible wall along the waterline
	WaterDepth = 14,
	SeaMargin = 700, -- terrain water past the land on every side
	FarSea = 30000, -- then flat water plates this far out, to the horizon
	FarSeaOverlap = 300, -- plates start this far inside the terrain water's edge
	FarSeaColor = Color3.fromRGB(98, 226, 232),
	Islets = 14, -- small wooded islands out in the water (within SeaMargin)
	FarLandDistance = 420, -- a wooded coast beyond the bridge, in the haze

	GateWidth = 16,
	FencePostSpacing = 8,
	WallHeight = 16, -- invisible wall above the fence (no jumping over)
	ShoreRocks = 60,

	-- What stands next to the road just past each gate (`After` studs past
	-- it, Side 1 = right, -1 = left, `Gap` studs from the road edge). The
	-- Front Yard counts from the road start; its shop is the house.
	Stations = {
		Sell = { After = 18, Side = 1, Gap = 2 },
		Shop = { After = 34, Side = -1, Gap = 12 },
		-- Kept free for a future quick-travel pad (not built yet).
		Travel = { After = 10, Side = -1, Gap = 1, Radius = 7 },
		Sign = { After = -12, Side = 1, Gap = 6 }, -- the area's name, before its gate
	},

	Areas = {
		front_yard = {
			Length = 170,
			HalfWidth = 62,
			Lawns = { Verge = 6, Rim = 10, Holes = 2 },
			Props = { "Shed", "Planters" }, -- the house is placed at the road start (ShopAt)
			ShopAt = "House",
			Trees = 26,
			Patches = { lucky = 0.002, golden = 0.0006, next = 0.0024 },
		},
		backyard = {
			Length = 200,
			HalfWidth = 72,
			Lawns = { Verge = 6, Rim = 11, Holes = 3 },
			Props = { "Pond", "Planters", "Shed" },
			Trees = 30,
			Patches = { lucky = 0.0025, golden = 0.0008, next = 0.0024 },
		},
		sunny_farm = {
			Length = 240,
			HalfWidth = 86,
			Lawns = { Verge = 7, Rim = 12, Holes = 3 },
			Props = { "Barn", "Silo", "Hay" },
			Trees = 34,
			Patches = { lucky = 0.0025, golden = 0.0008, next = 0.0021 },
		},
		big_ranch = {
			Length = 270,
			HalfWidth = 100,
			Lawns = { Verge = 7, Rim = 12, Holes = 4 },
			Props = { "RanchHouse", "WaterTower", "Hay" },
			Trees = 38,
			Patches = { lucky = 0.003, golden = 0.001, next = 0.0018 },
		},
		golf_estate = {
			Length = 300,
			HalfWidth = 112,
			Lawns = { Verge = 8, Rim = 13, Holes = 4 },
			Props = { "Mansion", "PuttingGreen", "Bunker", "Bunker" },
			Trees = 42,
			Patches = { lucky = 0.003, golden = 0.0012, next = 0.0018 },
		},
		mega_fields = {
			Length = 360,
			HalfWidth = 126,
			Lawns = { Verge = 8, Rim = 14, Holes = 5 },
			Props = { "Hangar", "TallSilo", "TallSilo", "Turbine", "Turbine" },
			Trees = 46,
			Patches = { lucky = 0.0035, golden = 0.0015 },
		},
	} :: { [string]: AreaDef },
}

return MapLayout
