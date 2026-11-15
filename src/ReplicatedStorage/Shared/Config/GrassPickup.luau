--!strict
-- The grass you just cut, flying into your pocket (GrassPickup.luau on the
-- client). One blade per unit of grass stored by the swing, so the starter
-- tools read exactly: 1 blade, then 2, 3, 4... Bigger hauls cap at
-- MaxBlades per swing and the "+N" popup carries the number.
return {
	MaxBlades = 12, -- blades drawn for one swing
	PoolSize = 72, -- blades alive at once (fast machines share them)
	Blade = Vector3.new(0.22, 2.3, 0.75), -- one blade: thickness, height, width
	Glow = true, -- Neon, so a blade stands out against the lawn it came from
	Brightness = 0.7, -- x the grass color (Neon at full color glows almost white)
	Stagger = 0.07, -- seconds between blades, so they can be counted
	PopSeconds = 0.22, -- jumps out of the lawn...
	PopHeight = 4.4, -- clear of the tallest grass
	HoldSeconds = 0.25, -- ...hangs for a moment...
	FlySeconds = 0.35, -- ...and flies to the player
	EndScale = 0.3, -- size when it reaches the player
	Spread = 0.8, -- studs between blades that leave the same spot
	Target = Vector3.new(0, 0.4, 0), -- where on the player they land (from the root)
	-- "+N" over the player's head; swings closer together than Every are summed.
	Popup = { Every = 0.4, Seconds = 0.8, Lift = 3, Rise = 1.5, Size = Vector2.new(150, 40) },
}
