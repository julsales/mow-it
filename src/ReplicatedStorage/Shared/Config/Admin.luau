--!strict
-- Who gets the admin test panel (AdminService / AdminPanel.client).
-- In Studio everyone is an admin (playtests); on live servers only these
-- user ids and members of the game's group at MinGroupRank or above.

return {
	UserIds = { 4304640820 }, -- julsales
	GroupId = 152627407, -- owner of the experience
	MinGroupRank = 254,
	Coins = { 1_000, 1_000_000, 1_000_000_000, 1_000_000_000_000 }, -- the coin buttons
	Xp = 100_000, -- per "+XP" press
	FastWalkSpeed = 48,
}
