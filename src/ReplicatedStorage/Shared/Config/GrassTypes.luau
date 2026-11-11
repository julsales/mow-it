--!strict
-- Grass types a lawn cell can grow. Every area already grows its own
-- tougher, more valuable grass (Zones.luau: GrassHealth, GrassValue); these
-- types are the lucky extras that pop up anywhere by chance (chances per
-- area in MapLayout.luau). A cut cell yields `Yield` grass instead of 1.

export type GrassType = {
	Id: string,
	DisplayName: string,
	HealthMultiplier: number, -- x the area's GrassHealth
	Yield: number, -- grass gained when cut
	Color: Color3?, -- sparkle color for rare types (nil = plain lawn)
}

local List: { GrassType } = {
	{ Id = "normal", DisplayName = "Grass", HealthMultiplier = 1, Yield = 1 },
	{ Id = "lucky", DisplayName = "Lucky Clover", HealthMultiplier = 1.5, Yield = 4, Color = Color3.fromRGB(110, 255, 140) },
	{ Id = "golden", DisplayName = "Golden Grass", HealthMultiplier = 2.5, Yield = 15, Color = Color3.fromRGB(255, 214, 70) },
}

local ById: { [string]: GrassType } = {}
for _, def in List do
	ById[def.Id] = def
end

return { List = List, ById = ById }
