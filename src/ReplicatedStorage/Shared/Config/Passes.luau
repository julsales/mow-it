--!strict
-- This universe currently has no passes (verified with Open Cloud).
-- Set an ID only after creating the matching permanent offer. Prices are read
-- from MarketplaceService per player, never copied from a UI reference.
return {
	-- Enable only after server entitlement effects are implemented and tested.
	CheckoutEnabled = false,
	List = {
		{ Id = "double_coins", GamePassId = 0, DisplayName = "2x Coins", Description = "Double the Coins your company earns.", Icon = "Coin", Color = "Gold", CoinMultiplier = 2, Featured = true },
		{ Id = "extra_crew", GamePassId = 0, DisplayName = "+2 Crew Slots", Description = "Bring two more helpers along on every job.", Icon = "Crew", Color = "Blue", CrewSlots = 2 },
		{ Id = "auto_sell", GamePassId = 0, DisplayName = "Auto-Sell", Description = "Sell harvested grass automatically when storage fills.", Icon = "Grass", Color = "Green" },
		{ Id = "infinite_fuel", GamePassId = 0, DisplayName = "Infinite Fuel", Description = "Keep motorized tools running without refueling.", Icon = "Fuel", Color = "Coral" },
	},
}
