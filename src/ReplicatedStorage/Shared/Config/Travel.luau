--!strict
-- Boat travel, as data. Every island past the home one has a jetty with a
-- rowboat beside the bridge you arrive on, and every personal base has
-- one too: step onto a jetty and sail HOME (to your base), or from your
-- base's jetty to any island you have unlocked. So nobody walks the whole
-- chain of islands to sell their bales.

local Travel = {
	-- The islands' jetties: `Along` studs round the coast from where the
	-- bridge arrives (on the side away from the drop-off pad), `Length`
	-- studs out to sea.
	Jetty = { Along = 30, Length = 24 },

	Distance = 16, -- studs from a jetty's deck within which its boat can be taken
	SailSeconds = 1.6, -- the trip (the screen shows the sea meanwhile)
	Cooldown = 3, -- seconds between trips

	HomeAction = "Sail home",
	AwayAction = "Sail to an island",
	ObjectText = "Rowboat",
	PickerTitle = "SAIL TO",
	Sailing = "Sailing to %s...",
	HomeName = "your island",
	Sea = Color3.fromRGB(64, 196, 214), -- the curtain while sailing
}

return Travel
