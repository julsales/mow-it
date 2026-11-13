--!strict
-- This universe currently has no passes (verified with Open Cloud).
-- Set an ID only after creating the matching permanent offer. Prices are read
-- from MarketplaceService per player, never copied from a UI reference.
return {
	-- Enable only after server entitlement effects are implemented and tested.
	CheckoutEnabled = false,
	List = {
		{ Id = "double_coins", GamePassId = 0, DisplayName = "2x Coins", Description = "Double your coins from every sale.", Icon = "Coins", Color = "Gold", CoinMultiplier = 2, Featured = true },
		{ Id = "extra_crew", GamePassId = 0, DisplayName = "+2 Crew Slots", Description = "Bring two extra helpers along.", Icon = "Crew", Color = "Blue", CrewSlots = 2 },
		{ Id = "auto_sell", GamePassId = 0, DisplayName = "Auto-Sell", Description = "Sell automatically as you mow.", Icon = "Grass", Color = "Green" },
		{ Id = "infinite_fuel", GamePassId = 0, DisplayName = "Infinite Fuel", Description = "Keep motorized tools running.", Icon = "Fuel", Color = "Coral" },
	},
	-- Shown after the real passes so the grid never ends on a gap.
	Upcoming = { Id = "upcoming", DisplayName = "More to grow", Description = "New passes coming later.", Icon = "Passes", Color = "Teal", Action = "Stay tuned" },
}
