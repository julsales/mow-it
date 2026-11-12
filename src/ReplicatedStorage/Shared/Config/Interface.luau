--!strict
-- Owner's farm-stall reference: docs/art/ui-reference.png.
return {
	Colors = {
		Ink = Color3.fromRGB(42, 32, 24), Cream = Color3.fromRGB(251, 243, 223),
		CreamShade = Color3.fromRGB(217, 199, 154), Track = Color3.fromRGB(228, 214, 174),
		Green = Color3.fromRGB(127, 166, 90), GreenShade = Color3.fromRGB(76, 133, 48),
		Leaf = Color3.fromRGB(183, 224, 140), Gold = Color3.fromRGB(242, 199, 92),
		Coral = Color3.fromRGB(199, 98, 63), Blue = Color3.fromRGB(63, 106, 151),
		Wood = Color3.fromRGB(169, 116, 79),
		Sky = Color3.fromRGB(99, 169, 209), Peach = Color3.fromRGB(223, 134, 94),
	},
	PanelMaxSize = Vector2.new(650, 620),
	NavigationWidth = 184,
	MinTarget = 44,
	Hud = {
		CompactHeight = 500, Edge = 16, ResourceWidth = 244, ResourceRow = 42,
		IconSize = 38, TrackerTop = 100, TrackerWidth = 260,
		NavigationTop = 0.26, NavigationMaxTop = 210,
		NavigationCell = Vector2.new(88, 88), CompactNavigationCell = Vector2.new(60, 60),
		NavigationGap = 8, NavigationIcon = 56, CompactNavigationIcon = 44,
		CompactNavigationTop = 8, CurrencyGap = 8, CurrencyIcon = 44, CompactCurrencyIcon = 28,
		CurrencyText = 30, CompactCurrencyText = 24,
		PanelHeaderHeight = 64, RewardDayHeight = 104,
	},
	NavigationColors = { Crew = "Green", Shop = "Gold", Jobs = "Sky", Rewards = "Peach" },
	Shop = { BannerHeight = 156, FeaturedHeight = 184, CompactWidth = 460, IconSize = 104, CompactIconSize = 72 },
	-- Set only after source PNG review and upload. Never invent Roblox IDs.
	Images = {
		-- Text-free OpenPencil exports are ready in assets/UI/. Populate only
		-- after upload; the same widgets use native shapes while IDs are absent.
		Chrome = {},
		Shop = "rbxassetid://81365167552895", Pack = "rbxassetid://106497497326342",
		Crew = "rbxassetid://116690514295516", Quests = "rbxassetid://135454624716672",
		Rewards = "rbxassetid://116852250146975", Clover = "rbxassetid://76980530708340",
		Coin = "rbxassetid://83148149561767", Grass = "rbxassetid://88698063189331",
		Fuel = "rbxassetid://119071119113757",
		Weather = {
			clear = "rbxassetid://137981988176543", rain = "rbxassetid://74120169894922",
			golden_sun = "rbxassetid://89745518785322", moon_night = "rbxassetid://121858425117652",
			storm = "rbxassetid://130409080893754",
		},
	},
}
