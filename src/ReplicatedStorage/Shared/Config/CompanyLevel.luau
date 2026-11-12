--!strict
-- Company Level (spec: private-land-progression). Experience comes from
-- cutting and selling (later also contracts and quests); the level gates
-- land expansions together with Coins (Zones.luau: RequiredLevel).
--
-- Curve: XP needed to go from level L to L+1 = BaseXp * Growth^(L-1).
-- With the numbers below the level a zone asks for arrives around the
-- time its Coin price does (XP is roughly 1.5x the Coins ever earned).

local CompanyLevel = {
	MaxLevel = 60,
	BaseXp = 500,
	Growth = 1.7,

	-- Sources ----------------------------------------------------------------
	XpPerCutValue = 1, -- per mowed cell: x the area's GrassValue (tougher lawns teach more)
	XpPerCoinSold = 0.5, -- per Coin earned at a sell pad
}

-- XP needed to finish `level` (math.huge at the cap, so the bar stays full).
function CompanyLevel.XpToNext(level: number): number
	if level >= CompanyLevel.MaxLevel then
		return math.huge
	end
	return math.floor(CompanyLevel.BaseXp * CompanyLevel.Growth ^ (level - 1))
end

return CompanyLevel
