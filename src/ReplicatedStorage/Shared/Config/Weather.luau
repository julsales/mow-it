--!strict
-- Server weather (spec: openspec/specs/weather-and-grass-variants).
-- Weather runs for the whole Land session and opens variant windows.

export type WeatherDef = {
	Id: string, DisplayName: string, DurationSeconds: number, Weight: number,
	VariantId: string, VariantChanceBonus: number,
}

local Weather: { WeatherDef } = {
	{ Id = "clear", DisplayName = "Clear Skies", DurationSeconds = 240, Weight = 50, VariantId = "normal", VariantChanceBonus = 0 },
	{ Id = "rain", DisplayName = "Rain", DurationSeconds = 180, Weight = 22, VariantId = "wet", VariantChanceBonus = 0.25 },
	{ Id = "golden_sun", DisplayName = "Golden Sun", DurationSeconds = 150, Weight = 14, VariantId = "golden", VariantChanceBonus = 0.12 },
	{ Id = "moon_night", DisplayName = "Moon Night", DurationSeconds = 180, Weight = 9, VariantId = "lunar", VariantChanceBonus = 0.10 },
	{ Id = "storm", DisplayName = "Storm", DurationSeconds = 120, Weight = 5, VariantId = "rainbow", VariantChanceBonus = 0.04 },
}

-- Variant sell multipliers, per tagged unit (spec: core-mowing-loop).
local VariantMultipliers: { [string]: number } = {
	normal = 1, wet = 2, golden = 20, lunar = 35, rainbow = 100, crystal = 150,
}

local byId: { [string]: WeatherDef } = {}
for _, w in Weather do byId[w.Id] = w end

return { List = Weather, ById = byId, VariantMultipliers = VariantMultipliers }
