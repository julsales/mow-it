--!strict
-- Carried grass, in one place for server and client (spec: core-mowing-loop,
-- "Tagged-variant inventory"). Grass is carried as a count per variant
-- (profile.GrassByVariant: normal, wet, golden, ...); storage capacity
-- counts the total across variants, and each variant sells for its own
-- multiplier (Weather.luau: VariantMultipliers).

local Config = script.Parent:WaitForChild("Config")
local Backpacks = require(Config.Backpacks)
local Weather = require(Config.Weather)
local GameConfig = require(Config.GameConfig)

local GrassBag = {}

GrassBag.DefaultVariant = "normal"

type Carrier = { GrassByVariant: { [string]: number }, EquippedBackpackId: string }

-- Total units carried, all variants.
function GrassBag.Total(profile: Carrier): number
	local total = 0
	for _, count in profile.GrassByVariant do
		total += count
	end
	return total
end

function GrassBag.Capacity(profile: Carrier): number
	local pack = Backpacks.ById[profile.EquippedBackpackId]
	return pack and pack.Capacity or 10
end

function GrassBag.IsFull(profile: Carrier): boolean
	return GrassBag.Total(profile) >= GrassBag.Capacity(profile)
end

-- 0..1, how full storage is.
function GrassBag.FillRatio(profile: Carrier): number
	return math.clamp(GrassBag.Total(profile) / math.max(GrassBag.Capacity(profile), 1), 0, 1)
end

-- Adds up to `amount` units of a variant, respecting capacity. Returns how
-- many units fit.
function GrassBag.Add(profile: Carrier, variantId: string, amount: number): number
	local room = GrassBag.Capacity(profile) - GrassBag.Total(profile)
	local stored = math.clamp(amount, 0, math.max(room, 0))
	if stored > 0 then
		profile.GrassByVariant[variantId] = (profile.GrassByVariant[variantId] or 0) + stored
	end
	return stored
end

-- Coins for everything carried: each variant pays its own multiplier, on
-- top of the area value.
function GrassBag.SellValue(profile: Carrier, areaValue: number): number
	local value = 0
	for variantId, count in profile.GrassByVariant do
		value += count * (Weather.VariantMultipliers[variantId] or 1)
	end
	return value * GameConfig.SellValuePerGrass * areaValue
end

function GrassBag.Clear(profile: Carrier)
	table.clear(profile.GrassByVariant)
end

return GrassBag
