--!strict
-- Rarity, as data: one ladder of seven tiers shown as stars. 0 stars is the
-- starter tier (drawn as a single empty star); 6 stars is the top.
-- Tools carry `Stars` (Config/Tools.luau); crew carry the tier's Id as
-- `Rarity` (Config/Crew.luau). Colors here are the only rarity colors: the
-- backpack rims, the shop rows and the world price tags all read them.

export type Tier = { Stars: number, Id: string, DisplayName: string, Color: Color3 }

local function hex(value: string): Color3 return Color3.fromHex(value) end

local Tiers: { Tier } = {
	{ Stars = 0, Id = "Starter", DisplayName = "Starter", Color = hex("8FA8B3") },
	{ Stars = 1, Id = "Common", DisplayName = "Common", Color = hex("D7E6EC") },
	{ Stars = 2, Id = "Uncommon", DisplayName = "Uncommon", Color = hex("8DD737") },
	{ Stars = 3, Id = "Rare", DisplayName = "Rare", Color = hex("35B6FF") },
	{ Stars = 4, Id = "Epic", DisplayName = "Epic", Color = hex("C066FF") },
	{ Stars = 5, Id = "Legendary", DisplayName = "Legendary", Color = hex("FFB721") },
	{ Stars = 6, Id = "Mythic", DisplayName = "Mythic", Color = hex("FF5A7A") },
}

local Rarity = {
	List = Tiers,
	MaxStars = #Tiers - 1,
	FilledStar = "★",
	EmptyStar = "☆",
	ByStars = {} :: { [number]: Tier },
	ById = {} :: { [string]: Tier },
	Colors = {} :: { [string]: Color3 }, -- by tier Id
}

for _, tier in Tiers do
	Rarity.ByStars[tier.Stars] = tier
	Rarity.ById[tier.Id] = tier
	Rarity.Colors[tier.Id] = tier.Color
end

-- The tier for a star count (clamped to the ladder).
function Rarity.Of(stars: number?): Tier
	return Rarity.ByStars[math.clamp(math.floor(stars or 0), 0, Rarity.MaxStars)]
end

-- "☆" for 0 stars, otherwise one filled star per star.
function Rarity.StarText(stars: number?): string
	local tier = Rarity.Of(stars)
	return if tier.Stars == 0 then Rarity.EmptyStar else string.rep(Rarity.FilledStar, tier.Stars)
end

-- How many glyphs StarText draws (to size a label).
function Rarity.StarCount(stars: number?): number
	return math.max(1, Rarity.Of(stars).Stars)
end

return Rarity
