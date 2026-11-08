--!strict
-- Timed client contracts (spec: openspec/specs/contracts).
-- Bands scale yard size/deadline/rewards; party size scales the target.

local Contracts = {
	Bands = {
		{ Id = "small_yard", DisplayName = "Neighbor's Yard", MinExpansion = 1, GrassTarget = 200, DeadlineSeconds = 300, Coins = 800, Clovers = 10, Xp = 40 },
		{ Id = "family_house", DisplayName = "Family House", MinExpansion = 2, GrassTarget = 800, DeadlineSeconds = 420, Coins = 4_000, Clovers = 30, Xp = 120 },
		{ Id = "farmstead", DisplayName = "Farmstead", MinExpansion = 3, GrassTarget = 3_000, DeadlineSeconds = 540, Coins = 18_000, Clovers = 90, Xp = 350 },
		{ Id = "ranch_job", DisplayName = "Ranch Job", MinExpansion = 4, GrassTarget = 9_000, DeadlineSeconds = 660, Coins = 70_000, Clovers = 260, Xp = 900 },
		{ Id = "estate_job", DisplayName = "Estate Grounds", MinExpansion = 5, GrassTarget = 25_000, DeadlineSeconds = 780, Coins = 280_000, Clovers = 800, Xp = 2_400 },
		{ Id = "mega_contract", DisplayName = "Mega Fields Contract", MinExpansion = 6, GrassTarget = 80_000, DeadlineSeconds = 900, Coins = 1_200_000, Clovers = 2_500, Xp = 6_000 },
	},
	-- Missing the deadline pays this fraction instead of failing hard.
	LatePayoutFraction = 0.4,
	-- Party target multiplier per extra member (less than linear: co-op is faster).
	PartyTargetPerExtraMember = 0.7,
}

return Contracts
