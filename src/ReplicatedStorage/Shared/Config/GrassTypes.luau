--!strict
-- Grass, as data: how each kind of grass looks and what it is worth.
--
-- * Every area grows its own grass (Zones.luau: GrassHealth, GrassValue)
--   with its own look (`Looks[<zoneId>]`): color, height, blade shape.
-- * Patch types grow by luck in small patches anywhere (chances per area in
--   MapLayout.luau `Patches`): Lucky Clover, Golden Grass, and "next" =
--   the next area's grass showing up early (its health and look; it yields
--   more because it is worth more).
--
-- The server owns the type of every cell (GrassService); clients draw the
-- blades from `Looks` (GrassTufts.luau). A cut cell yields `Yield` grass.

export type Shape = "Blade" | "Flower" | "Stalk" | "Tuft" | "Clover"

export type Look = {
	Shape: Shape,
	Color: Color3, -- blade color
	Tip: Color3?, -- flower / ear / tip color
	Height: number, -- studs above the lawn
	Width: number, -- blade width
	Blades: number, -- blades per 4x4 cell
	Glow: boolean?, -- Neon blades (rare grass shines)
	Sparkle: Color3?, -- sparkles above the cell (seen from far away)
}

export type GrassType = {
	Id: string,
	DisplayName: string,
	HealthMultiplier: number, -- x the health of the grass it replaces
	Yield: number, -- grass gained when cut ("next" works it out from values)
	PatchRadius: number, -- patch size, in cells around the lucky one
	Look: string?, -- key in Looks (nil = the area's own look / the next area's)
}

local Looks: { [string]: Look } = {
	-- Area grass, one per Zones.luau id: each one reads different at a glance.
	front_yard = { Shape = "Blade", Color = Color3.fromRGB(132, 204, 84), Tip = Color3.fromRGB(176, 226, 116), Height = 2.4, Width = 0.5, Blades = 3 },
	backyard = { Shape = "Flower", Color = Color3.fromRGB(56, 144, 66), Tip = Color3.fromRGB(255, 232, 110), Height = 2.6, Width = 0.6, Blades = 3 },
	sunny_farm = { Shape = "Stalk", Color = Color3.fromRGB(204, 184, 88), Tip = Color3.fromRGB(236, 204, 104), Height = 3.2, Width = 0.3, Blades = 3 },
	big_ranch = { Shape = "Tuft", Color = Color3.fromRGB(150, 160, 66), Tip = Color3.fromRGB(196, 176, 98), Height = 3.4, Width = 1.1, Blades = 3 },
	golf_estate = { Shape = "Blade", Color = Color3.fromRGB(24, 160, 112), Tip = Color3.fromRGB(80, 206, 150), Height = 2.6, Width = 0.5, Blades = 6 },
	mega_fields = { Shape = "Stalk", Color = Color3.fromRGB(64, 120, 64), Tip = Color3.fromRGB(176, 120, 226), Height = 4.2, Width = 0.4, Blades = 3 },
	-- Patch grass.
	lucky = { Shape = "Clover", Color = Color3.fromRGB(70, 220, 110), Tip = Color3.fromRGB(255, 255, 255), Height = 2.6, Width = 1.3, Blades = 3, Glow = true, Sparkle = Color3.fromRGB(110, 255, 140) },
	golden = { Shape = "Blade", Color = Color3.fromRGB(255, 200, 50), Tip = Color3.fromRGB(255, 240, 160), Height = 3.6, Width = 0.7, Blades = 5, Glow = true, Sparkle = Color3.fromRGB(255, 214, 70) },
}

local List: { GrassType } = {
	{ Id = "normal", DisplayName = "Grass", HealthMultiplier = 1, Yield = 1, PatchRadius = 0 },
	{ Id = "lucky", DisplayName = "Lucky Clover", HealthMultiplier = 1.5, Yield = 4, PatchRadius = 1.5, Look = "lucky" },
	{ Id = "golden", DisplayName = "Golden Grass", HealthMultiplier = 2.5, Yield = 15, PatchRadius = 1.2, Look = "golden" },
	{ Id = "next", DisplayName = "Rare Grass", HealthMultiplier = 1, Yield = 2, PatchRadius = 2.3 },
}

local ById: { [string]: GrassType } = {}
for _, def in List do
	ById[def.Id] = def
end

-- Patch types are rolled rarest first.
local PatchOrder = { "golden", "lucky", "next" }

return { List = List, ById = ById, Looks = Looks, PatchOrder = PatchOrder }
