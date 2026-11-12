--!strict
-- Lobby showcase lots (spec: lobby-showcase-and-party). A lot is a small
-- public snapshot of a player's progress: a house that grows with their
-- land, their best tool parked in front and a sign with headline stats.
-- It is display only: nothing on a lot can be bought, sold or changed.

local Showcase = {
	LotSize = 22, -- studs, square
	HouseFit = 12, -- the house is scaled so its footprint fits this (studs)
	HandToolFit = 3.2, -- display size of a hand tool on its stand

	-- House per number of expansions unlocked (index 1 = only the Front
	-- Yard). Names are Props.Kinds builders.
	HouseByExpansions = { "Shed", "House", "Barn", "RanchHouse", "Mansion", "Hangar" },

	VacantText = "VACANT LOT",
	CompanySuffix = "'s Lawn Co.",
}

return Showcase
