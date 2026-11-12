--!strict
-- Franchise prestige (spec: openspec/specs/franchise-prestige).
-- Franchising resets Coins/tools/storage/expansions; NEVER Crew, cosmetics,
-- badges. Points buy permanent nodes below.

local Franchise = {
	-- Lifetime Coins earned in a run needed for the first point, and growth.
	FirstPointAtLifetimeCoins = 5_000_000,
	PointCostGrowth = 1.6,

	Nodes = {
		{ Id = "extra_crew_slot", DisplayName = "Bigger Crew", MaxRank = 3, CostPerRank = 1, Effect = "+1 Crew slot per rank" },
		{ Id = "offline_cap", DisplayName = "While You Were Out", MaxRank = 5, CostPerRank = 1, Effect = "+2h offline cap per rank (base 0h, automation adds more)" },
		{ Id = "crew_engine", DisplayName = "Crew Engine", MaxRank = 5, CostPerRank = 2, Effect = "+15% Crew power per rank" },
		{ Id = "golden_touch", DisplayName = "Golden Touch", MaxRank = 5, CostPerRank = 2, Effect = "+5% variant chance per rank" },
		{ Id = "head_start", DisplayName = "Head Start", MaxRank = 3, CostPerRank = 1, Effect = "Start with one extra expansion per rank (up to Big Ranch)" },
		{ Id = "company_multiplier", DisplayName = "Brand Value", MaxRank = 10, CostPerRank = 3, Effect = "+25% all Coin earnings per rank" },
	},
}

return Franchise
