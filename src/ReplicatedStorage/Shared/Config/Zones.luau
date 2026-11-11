--!strict
-- Zone ladder. The map is one continuous world divided by gates: you start
-- at a suburban house and end in fully-automated mega fields. Every new
-- zone pays more per grass, costs more to unlock, and stocks stronger
-- tools / backpacks / buffs (gated by RequiredZone in their own configs).

export type ZoneDef = {
	Id: string,
	DisplayName: string,
	Subtitle: string,
	UnlockPrice: number, -- Coins, 0 = open from the start
	RequiredLevel: number, -- Company Level (spec: private-land-progression)
	GrassValue: number, -- Coins per unit of grass sold from this zone
	GrassHealth: number, -- tool Power needed to clear one grass cell
	TuftCount: number, -- unused since grass became a full grid (GrassService); kept for old data
	ThemeColor: Color3, -- UI / sign accent for this zone
	GrassColor: Color3, -- color of the grass tufts (and graybox lawn) here
}

local Zones: { ZoneDef } = {
	{ Id = "front_yard", DisplayName = "Front Yard", Subtitle = "Your house. Your lawn. Your problem.", UnlockPrice = 0, RequiredLevel = 1, GrassValue = 1, GrassHealth = 1, TuftCount = 60, ThemeColor = Color3.fromRGB(106, 190, 74), GrassColor = Color3.fromRGB(96, 178, 70) },
	{ Id = "backyard", DisplayName = "Backyard Garden", Subtitle = "Flowers, fences and thicker grass.", UnlockPrice = 1_000, RequiredLevel = 2, GrassValue = 3, GrassHealth = 6, TuftCount = 80, ThemeColor = Color3.fromRGB(74, 170, 90), GrassColor = Color3.fromRGB(72, 160, 64) },
	{ Id = "sunny_farm", DisplayName = "Sunny Farm", Subtitle = "The neighbors will pay you now.", UnlockPrice = 15_000, RequiredLevel = 5, GrassValue = 8, GrassHealth = 25, TuftCount = 110, ThemeColor = Color3.fromRGB(232, 183, 75), GrassColor = Color3.fromRGB(138, 176, 62) },
	{ Id = "big_ranch", DisplayName = "Big Ranch", Subtitle = "Acres of it. All yours to cut.", UnlockPrice = 120_000, RequiredLevel = 9, GrassValue = 20, GrassHealth = 110, TuftCount = 140, ThemeColor = Color3.fromRGB(196, 132, 58), GrassColor = Color3.fromRGB(118, 150, 58) },
	{ Id = "golf_estate", DisplayName = "Golf Estate", Subtitle = "Rich people grass. Rich people prices.", UnlockPrice = 900_000, RequiredLevel = 14, GrassValue = 50, GrassHealth = 450, TuftCount = 170, ThemeColor = Color3.fromRGB(64, 160, 140), GrassColor = Color3.fromRGB(64, 186, 92) },
	{ Id = "mega_fields", DisplayName = "Mega Fields", Subtitle = "Automation country. Let the machines work.", UnlockPrice = 6_000_000, RequiredLevel = 20, GrassValue = 130, GrassHealth = 1_800, TuftCount = 220, ThemeColor = Color3.fromRGB(120, 110, 220), GrassColor = Color3.fromRGB(52, 136, 66) },
}

local byId: { [string]: ZoneDef } = {}
local indexById: { [string]: number } = {}
for i, zone in Zones do
	byId[zone.Id] = zone
	indexById[zone.Id] = i
end

return {
	List = Zones,
	ById = byId,
	IndexById = indexById,
}
