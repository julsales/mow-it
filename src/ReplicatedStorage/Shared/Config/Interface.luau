--!strict
-- Screen UI layout and look. Design source: docs/art/generated-v3/mow-it-ui-v3.fig
-- (OpenPencil boards 1-5, exports board-*.png next to it). Colors is the warm
-- world palette (billboards, confetti); Theme is the screen UI from the boards.
local function hex(value: string): Color3 return Color3.fromHex(value) end
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
	Theme = {
		Surface = hex("073746"), SurfaceStroke = hex("31D7EB"), Backdrop = hex("041C26"),
		Header = hex("07638F"), HeaderStroke = hex("35DDF4"),
		Card = hex("0F495B"), CardStroke = hex("2C8097"), QuestStroke = hex("2FB6D0"),
		Tile = hex("19576A"), TileStroke = hex("397E92"),
		TileActive = hex("366D20"), TileActiveStroke = hex("C5FF80"),
		TrackerStroke = hex("73D852"), TrackerHeader = hex("285D24"),
		Text = hex("FFFFFF"), TextMuted = hex("A6CBD7"), TextDark = hex("102D43"),
		Coins = hex("FFDE59"), Clovers = hex("C3FF8C"),
		Track = hex("1D5460"), Fill = hex("8DD737"),
		Outline = hex("1B2452"), Gloss = 0.72, Badge = hex("E0263A"),
		-- Button styles: fill and label color. Disabled is the quiet "Stay tuned" look.
		Buttons = {
			Blue = { Fill = hex("1F94E9"), Text = hex("071A28") },
			Purple = { Fill = hex("9822D5"), Text = hex("FFFFFF") },
			Green = { Fill = hex("67AE22"), Text = hex("102D43") },
			Progress = { Fill = hex("366D20"), Text = hex("FFFFFF") },
			Close = { Fill = hex("B51F3D"), Text = hex("FFFFFF") },
			Muted = { Fill = hex("28687A"), Text = hex("FFFFFF") },
			Disabled = { Fill = hex("245768"), Text = hex("C2E2EB"), Flat = true },
		},
		-- Pass card skins (banner-base multiplied by Fill; Gold uses offer-banner as is).
		Offers = {
			Gold = { Fill = hex("EFB52B"), Stroke = hex("F5D66B"), Text = hex("102D43"), Art = "OfferBanner", Rays = 0.76 },
			Blue = { Fill = hex("195C96"), Stroke = hex("67B1D3"), Text = hex("FFFFFF"), Art = "Banner", Rays = 0.88 },
			Green = { Fill = hex("326A1D"), Stroke = hex("88BE4B"), Text = hex("FFFFFF"), Art = "Banner", Rays = 0.88 },
			Coral = { Fill = hex("9E3948"), Stroke = hex("DA8591"), Text = hex("FFFFFF"), Art = "Banner", Rays = 0.88 },
			Teal = { Fill = hex("174C60"), Stroke = hex("387D91"), Text = hex("FFFFFF"), Art = "Banner", Rays = 0.88 },
		},
	},
	-- HUD menu tiles, top-left 2x2. Tint multiplies the silver button-base.
	Navigation = {
		{ Page = "Crew", Label = "CREW", Icon = "Crew", Tint = hex("238DE8") },
		{ Page = "Shop", Label = "SHOP", Icon = "Passes", Tint = hex("FFB721") },
		{ Page = "Jobs", Label = "QUESTS", Icon = "Quests", Tint = hex("9A4DE5") },
		{ Page = "Rewards", Label = "REWARDS", Icon = "Rewards", Tint = hex("DC46B6") },
	},
	-- Pixel sizes are the boards' 1440x900 values; Hud.Scale shrinks them
	-- on short screens (phones) so the left rail and panels still fit.
	PanelMaxSize = Vector2.new(860, 780),
	MinTarget = 44,
	Hud = {
		DesignHeight = 900, MinScale = 0.55, Edge = 16, Top = 24,
		Tile = 108, TileGap = 4, TileIcon = 84, TilePlate = Vector2.new(94, 27),
		RailTop = 222, PillGap = 13, Pill = Vector2.new(222, 62), PillIcon = 78, PillText = 34,
		Status = Vector2.new(216, 58), StatusIcon = 64, StatusText = 26, StatusGap = 12,
		Storage = Vector2.new(222, 54), StorageIcon = 64, StorageText = 26,
		Tracker = Vector2.new(272, 218), TrackerTop = 296, TrackerHeader = 55,
		Badge = Vector2.new(30, 52),
		WindowInset = 16, HeaderHeight = 68, HeaderIcon = 90, ButtonHeight = 44,
		RewardTile = Vector2.new(92, 142),
	},
	Passes = { Upper = 3, UpperHeight = 264, LowerHeight = 208, Gap = 12, Icon = 110, WideIcon = 112, CompactWidth = 560 },
	-- Uploaded from build/ui-upload (tools/prepare-ui-uploads.py). Never invent IDs.
	Images = {
		Window = "rbxassetid://93676969129473", Button = "rbxassetid://107710178245629",
		Banner = "rbxassetid://123322804337852", OfferBanner = "rbxassetid://102937455684089", Rays = "rbxassetid://123232615629642",
		Crew = "rbxassetid://138386967057872", Passes = "rbxassetid://136221907144285", Quests = "rbxassetid://130600195925880",
		Rewards = "rbxassetid://89118763452353", QuestAvailable = "rbxassetid://133854175476963",
		Coin = "rbxassetid://99987696561531", Coins = "rbxassetid://73230043456833", Clover = "rbxassetid://123117278274813",
		Grass = "rbxassetid://133405609113529", Fuel = "rbxassetid://134662035752654",
		Weather = {
			clear = "rbxassetid://135255857476832", rain = "rbxassetid://70764296626372", golden_sun = "rbxassetid://117623343175900",
			moon_night = "rbxassetid://134336277305826", storm = "rbxassetid://73862892989147",
		},
	},
	-- Slice rects of the uploaded skins (pixels of the upload-ready PNGs).
	Slices = { Window = Rect.new(40, 40, 472, 466) },
}
