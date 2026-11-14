--!strict
-- Personal bases, as data (Map/Bases builds them, BaseService hands them
-- out, Shared/Bases finds them).
--
-- The big islands are shared by everybody on the server; what is yours is
-- a small island of your own next to the home island: your cabin, your hay
-- yard (baler, bale stack, silo) and a jetty with your boat. One is built
-- per entry in `Headings`, in a fan around the home island, each joined to
-- it by a short bridge. A player gets a free one on joining and spawns
-- there; it is theirs until they leave.
--
-- A base's frame: origin on the ground at the island's center, +Z toward
-- the home island (the bridge side): the usual prop frame, "+Z = the front".
-- Distances are in studs.

local v3 = Vector3.new

export type TreeSpot = { Kind: string, At: Vector3, Scale: number }

local Bases = {
	-- Where they stand: directions from the home island's center (degrees
	-- clockwise from north). With the bridge to the next island (at 332)
	-- they make seven evenly spaced spokes round the home island. One base
	-- per row: this is also the server size.
	Headings = { 23.4, 74.9, 126.3, 177.7, 229.1, 280.6 },
	Gap = 30, -- water between the home island's coast and the base's coast

	-- The island: a rounded rectangle (superellipse), `Width` across and
	-- `Depth` away from the home island, narrowing toward the bridge, with
	-- a narrow beach.
	Width = 84,
	Depth = 110,
	Roundness = 3, -- 2 = an ellipse; higher = squarer corners
	Taper = 0.4, -- how much narrower the bridge end is (0 = not at all)
	Beach = 8,

	-- The bridge from the home island (narrower than the island bridges).
	-- `Inland`: how far in from the base's coast the deck lands (on the
	-- grass); `HomeInland`: the same on the home island (on its promenade).
	Bridge = { Width = 8, Inland = 9, HomeInland = 19 },

	-- What stands on it (base frame).
	Cabin = { Offset = CFrame.new(10, 0, -24), Scale = 0.85, Title = "My Loft" },
	-- The yard's own frame has the machines along X and the player in front
	-- (+Z). It stands on the left as a yard of its own, facing the middle
	-- of the island with grass between it and the walkway, its silo at the
	-- back, a short walk from the jetty the customers arrive at.
	Yard = { Offset = CFrame.new(-17, 0, 10) * CFrame.Angles(0, math.rad(90), 0) },
	Spawn = v3(0, 0, 40), -- where the owner appears, facing their cabin
	-- The jetty at the back, with the owner's boat: quick travel leaves from
	-- here and the silo's customers arrive here.
	Jetty = { Length = 24, Side = -22, Inland = 16 }, -- `Side`: studs off the island's middle line; `Inland`: where its deck starts
	-- The name board by the bridge: "<Name>'s Island", or VacantText.
	Sign = { At = v3(10, 0, 45), Size = v3(9, 2.4, 0.4), Height = 4.2 },
	VacantText = "FOR RENT",
	OwnerText = "%s's Island",
	CabinText = "%s's Loft", -- the sign over the cabin's porch
	-- The dirt path from the bridge to the cabin's steps: an S through `Via`.
	Walkway = { Width = 5, Via = { v3(8, 0, 32), v3(0, 0, 14) } },
	-- The owner's picture and name floating over the base (BaseService).
	Tag = {
		At = v3(0, 34, 0),
		Size = v3(22, 19, 0), -- studs: the picture on top, the name under it
		MaxDistance = 600,
		Surface = Color3.fromRGB(255, 244, 214), -- behind the picture
		Outline = Color3.fromRGB(74, 46, 22), -- ring and text outline
		Text = Color3.fromRGB(255, 255, 255),
	},
	-- A little lawn of the home island's grass (contract parts "GrassArea").
	Lawns = {
		{ Center = v3(18, 0, 26), Size = v3(11, 0, 24) },
		{ Center = v3(22, 0, 6), Size = v3(12, 0, 14) },
	},

	Trees = {
		{ Kind = "Tree", At = v3(33, 0, -6), Scale = 0.9 },
		{ Kind = "Tree", At = v3(-33, 0, -12), Scale = 0.8 },
		{ Kind = "Bush", At = v3(-29, 0, 30), Scale = 0.7 },
		{ Kind = "Flora", At = v3(-9, 0, 47), Scale = 0.8 },
		{ Kind = "Bush", At = v3(28, 0, 38), Scale = 0.6 },
	} :: { TreeSpot },

	-- Promenade on the home island: a dirt path along the coast, `Inland`
	-- studs in, joining every base's bridge to the main path.
	Promenade = { Inland = 21, Width = 6 },
}

return Bases
