--!strict
-- The hay yard at the player's base: how grass is sold (spec
-- core-mowing-loop "Selling grass", plan in docs/HAY_YARD.md).
--
--   grass -> BALER (presses bales) -> the STACK (click a bale to sell it)
--         -> bale rides the elevator into the SILO -> customers walk up
--            and buy from the silo (a tip on top of the sale).
--
-- Everything here is data: the numbers of the loop, the machine's upgrade
-- ladder, and how the Blender models (art/yard/) are painted, put together
-- and animated. Systems read it; nothing is hard-coded in them.

local ToolArt = require(script.Parent.ToolArt)

local rgb = Color3.fromRGB
local v3 = Vector3.new

export type Level = {
	Price: number, -- Coins to reach this level
	RequiredZone: number, -- island (index in Zones.luau) that must be unlocked first
	BaleSeconds: number, -- time the baler needs per press
	Batch: number, -- bales that come out of one press
	Layers: number, -- bale layers the stack holds (6 bales per layer)
}

export type ModelDef = ToolArt.ModelDef

export type RigDef = {
	-- How the piece moves (StarterPlayerScripts/HayRigs):
	--   Spin   turns around Axis; the value is its speed (rad/s)
	--   Shake  rattles around its pivot; value 0..1 = how hard
	--   Slide  moves along Axis by Travel * value
	--   Swing  turns around Axis by Angle (degrees) * value
	--   Loop   moves along Axis at speed `value`, wrapping every Travel studs
	--   Grow   scales around its pivot by `value` (0 = gone)
	Kind: "Spin" | "Shake" | "Slide" | "Swing" | "Loop" | "Grow",
	Axis: Vector3?,
	Travel: number?,
	Angle: number?,
	Parent: string?, -- rig this one is mounted on (moves with it)
}

export type Box = { Center: Vector3, Size: Vector3, Tilt: number?, Round: boolean? }
export type Sign = { Center: Vector3, Size: Vector3, Text: string, Rig: string?, Name: string }

export type PieceDef = {
	Model: string, -- Models row
	Offset: CFrame, -- where it stands in the yard (yard frame: origin on the ground, +Z = front)
	Rigs: { [string]: RigDef },
	Markers: { [string]: Vector3 }, -- named points, in the model's authored coordinates
	Colliders: { Box }, -- invisible walls (the meshes themselves are walk-through)
	Signs: { Sign },
}

local elevatorFoot, elevatorTop = v3(-10.3, 1.35, 0), v3(-4.0, 7.75, 0)

local HayYard = {
	-- The loop ---------------------------------------------------------------
	GrassPerBale = 5, -- smallest bale, in grass units
	BalesPerFullBag = 6, -- a full storage always makes about this many bales (bigger bags = richer bales)
	GoldenChance = 0.04, -- chance a bale comes out golden
	GoldenMultiplier = 5,
	SellDistance = 48, -- how close to the stack a click still sells (studs)
	HintDistance = 70, -- the "what to do next" banner shows this close to the yard
	SiloCapacity = 30, -- bales the silo keeps in stock for customers
	TipRate = 0.1, -- customers pay this share of the bales' value on top
	CustomerEvery = { Min = 5, Max = 9 }, -- seconds between customers while the silo has stock
	CustomerBales = { Min = 1, Max = 2 }, -- bales one customer buys (two fit under the counter's awning)
	CustomerWalkSeconds = 6, -- from the spawn marker to the counter; the tip lands then
	CustomerSpeed = { Min = 7, Max = 16 }, -- studs/s limits when matching that time

	-- Baler upgrades (profile.Hay.Level), bought at the baler. A level can
	-- only be bought once the island `RequiredZone` (index in Zones.luau) is
	-- unlocked, so the machine grows with the land.
	Levels = {
		{ Price = 0, RequiredZone = 1, BaleSeconds = 2.4, Batch = 1, Layers = 2 },
		{ Price = 400, RequiredZone = 1, BaleSeconds = 2.2, Batch = 1, Layers = 3 },
		{ Price = 4_000, RequiredZone = 2, BaleSeconds = 2.0, Batch = 2, Layers = 3 },
		{ Price = 50_000, RequiredZone = 3, BaleSeconds = 1.8, Batch = 2, Layers = 4 },
		{ Price = 400_000, RequiredZone = 4, BaleSeconds = 1.6, Batch = 3, Layers = 4 },
		{ Price = 3_000_000, RequiredZone = 5, BaleSeconds = 1.4, Batch = 3, Layers = 5 },
		{ Price = 20_000_000, RequiredZone = 6, BaleSeconds = 1.2, Batch = 4, Layers = 5 },
	} :: { Level },

	-- The stack on the pallet: columns across (X) and deep (Z), bale size.
	Stack = {
		Columns = { v3(-2.55, 0, 0.82), v3(0, 0, 0.82), v3(2.55, 0, 0.82), v3(-2.55, 0, -0.78), v3(0, 0, -0.78), v3(2.55, 0, -0.78) },
		Top = 0.54, -- pallet surface
		BaleHeight = 1.5,
	},

	-- Art ----------------------------------------------------------------------
	-- Rows written by art/yard/sync_config.py (ids from out/assets.json, boxes
	-- and pivots from out/meta.json). AssetId 0 = not uploaded yet.
	Models = {
		bale = { AssetId = 78418165538120, Center = Vector3.new(0, 0.765, 0), Size = Vector3.new(2.766, 1.53, 1.56) },
		baler = { AssetId = 111855121608229, Center = Vector3.new(0.421, 3.745, 1.225), Size = Vector3.new(11.122, 7.49, 7.15), Pivots = { Cap = Vector3.new(1.66, 7.44, -0.9), Flywheel = Vector3.new(-1.3, 3, 2.035), Heap = Vector3.new(-1.6, 6.45, -0), Needle = Vector3.new(1.9, 3.75, 1.87), Plunger = Vector3.new(2.6, 5.3, -0), Shake = Vector3.new(-0.2, 3, -0) } },
		pallet = { AssetId = 126116120776841, Center = Vector3.new(0, 1.695, -0.025), Size = Vector3.new(8, 3.39, 3.75) },
		silo = { AssetId = 88677231845583, Center = Vector3.new(-3.65, 8.525, 0.714), Size = Vector3.new(15.3, 17.05, 9.428), Pivots = { Belt = Vector3.new(-9.95, 1.848, -0), Hatch = Vector3.new(-3.86, 9.95, -0), Vane = Vector3.new(-0, 16.75, -0) } },
	} :: { [string]: ModelDef },

	-- Colours and materials by mesh name; names missing here use the tools'
	-- shared pieces (Config/ToolArt.Pieces: Metal, Chrome, Dark, Rubber, Wood…).
	Paint = {
		Accent = { Color = rgb(206, 70, 54), Material = Enum.Material.SmoothPlastic },
		Accent2 = { Color = rgb(250, 200, 70), Material = Enum.Material.SmoothPlastic },
		Body = { Color = rgb(240, 228, 198), Material = Enum.Material.SmoothPlastic },
		Roof = { Color = rgb(180, 64, 52), Material = Enum.Material.SmoothPlastic },
		Hay = { Color = rgb(178, 196, 92), Material = Enum.Material.SmoothPlastic }, -- fresh-cut grass, not dry hay
		Straw = { Color = rgb(214, 224, 128), Material = Enum.Material.SmoothPlastic },
		Twine = { Color = rgb(128, 88, 54), Material = Enum.Material.Fabric },
		Grass = { Color = rgb(112, 178, 72), Material = Enum.Material.SmoothPlastic },
		Lamp = { Color = rgb(120, 110, 100), Material = Enum.Material.SmoothPlastic },
	} :: { [string]: ToolArt.Piece },
	GoldenBale = { Hay = rgb(255, 204, 60), Straw = rgb(255, 236, 150), Twine = rgb(214, 120, 40), Material = Enum.Material.Metal, Reflectance = 0.25 },
	Lamp = { Idle = rgb(120, 110, 100), Working = rgb(255, 170, 40), Full = rgb(255, 80, 60) },

	-- The yard's pieces. Each becomes its own Model inside the HayYard Model
	-- (docs/EDITING.md): drag them freely, the animations follow.
	Pieces = {
		Baler = {
			Model = "baler",
			Offset = CFrame.new(-11, 0, 0),
			Rigs = {
				Shake = { Kind = "Shake" },
				Flywheel = { Kind = "Spin", Axis = Vector3.zAxis, Parent = "Shake" },
				Plunger = { Kind = "Slide", Axis = Vector3.yAxis, Travel = 0.95, Parent = "Shake" },
				Cap = { Kind = "Swing", Axis = Vector3.zAxis, Angle = 55, Parent = "Shake" },
				Needle = { Kind = "Swing", Axis = Vector3.zAxis, Angle = -110, Parent = "Shake" },
				Heap = { Kind = "Grow", Parent = "Shake" },
			},
			Markers = {
				Hopper = v3(-1.6, 6.6, 0), -- grass is thrown in here
				Mouth = v3(2.3, 2.8, 0), -- a bale starts inside the chamber…
				Tray = v3(4.62, 2.8, 0), -- …and slides out to here
				Exhaust = v3(1.9, 7.55, -0.9),
				Stand = v3(-1.6, 0.54, 3.6), -- the loading deck
			},
			Colliders = {
				{ Center = v3(-0.2, 3.2, 0), Size = v3(6.6, 6.4, 3.8) },
				{ Center = v3(4.6, 1.15, 0), Size = v3(2.8, 2.3, 2.1) },
				{ Center = v3(-1.6, 0.27, 3.6), Size = v3(4.4, 0.54, 2.4) },
			},
			Signs = {
				{ Name = "Sign", Center = v3(0.72, 2.95, 1.72), Size = v3(1.5, 0.66, 0.08), Text = "BALER", Rig = "Shake" },
			},
		},
		BaleStack = {
			Model = "pallet",
			Offset = CFrame.new(0.4, 0, 0),
			Rigs = {},
			Markers = {},
			Colliders = {
				{ Center = v3(0, 0.27, 0), Size = v3(8, 0.54, 3.7) },
				{ Center = v3(0, 1.7, -1.75), Size = v3(8, 3.4, 0.3) },
			},
			Signs = {},
		},
		Silo = {
			Model = "silo",
			Offset = CFrame.new(9.5, 0, -7.5),
			Rigs = {
				Belt = { Kind = "Loop", Axis = (elevatorTop - elevatorFoot).Unit, Travel = 1.2 },
				Hatch = { Kind = "Swing", Axis = Vector3.zAxis, Angle = -75 },
				Vane = { Kind = "Spin", Axis = Vector3.yAxis },
			},
			Markers = {
				ElevatorFoot = elevatorFoot, -- on the belt, where a sold bale lands
				ElevatorTop = elevatorTop,
				Inside = v3(-2.6, 8.3, 0), -- past the hatch
				Window = v3(0, 3.65, 3.2), -- the serving hatch
				Counter = v3(0, 2.78, 4.35), -- top of the counter
				Customer = v3(0, 0, 7.2), -- where a customer stands
			},
			Colliders = {
				{ Center = v3(0, 6.5, 0), Size = v3(7.4, 13, 7.4), Round = true },
				{ Center = v3(-10.45, 0.8, 0), Size = v3(1.7, 1.6, 2.3) },
				{ Center = (elevatorFoot + elevatorTop) / 2 - v3(0, 0.35, 0), Size = v3(9.4, 0.5, 2.1), Tilt = math.deg(math.atan2(elevatorTop.Y - elevatorFoot.Y, elevatorTop.X - elevatorFoot.X)) },
				{ Center = v3(0, 1.4, 4.3), Size = v3(5.6, 2.8, 1.7) },
			},
			Signs = {
				{ Name = "Sign", Center = v3(0, 8.0, 3.5), Size = v3(4.8, 1.5, 0.5), Text = "HAY FOR SALE" },
			},
		},
	} :: { [string]: PieceDef },

	-- Where the player hands grass in: the contract part "SellPad", an
	-- invisible box on the baler's loading deck (baler coordinates). It is
	-- smaller than the deck because EconomyService counts a pad as reached 2
	-- studs around it. The deck itself glows with an outline (HayYard.client).
	LoadZone = { Piece = "Baler", Center = v3(-1.6, 2.6, 3.6), Size = v3(1.4, 5, 0.5) },
	DeckPiece = "Wood", -- the baler mesh that is the loading deck
	Outline = rgb(255, 214, 90), -- outline of the deck and of the bales waiting to be sold
	-- Customers walk in from the invisible "CustomerSpawn" marker (drag it
	-- in Studio); built this far from the silo's counter.
	CustomerSpawn = v3(6, 0, 34),
	-- Packed dirt under the yard (thin parts like the paths): rounded
	-- rectangles in the yard frame, `Corner` studs of rounding.
	Ground = {
		Corner = 2.5,
		Color = rgb(214, 176, 122),
		Pads = {
			{ Center = v3(-4.8, 0, 1.6), Size = v3(25.5, 0, 10) }, -- baler and stack
			{ Center = v3(6.3, 0, -6.2), Size = v3(20, 0, 13) }, -- silo and elevator
			{ Center = v3(9.5, 0, 2.6), Size = v3(10, 0, 7) }, -- in front of the counter
		},
	},
	-- The yard stands this far from where an island's sell pad would be
	-- (back from the path, which bulges toward that spot).
	StationOffset = CFrame.new(0, 0, -8),
	-- Room the yard needs on a freshly generated island (MapService).
	Radius = 20,

	-- Who shops at the silo (default R15 bodies, like the farmers).
	Customers = {
		{ Shirt = rgb(214, 86, 70), Pants = rgb(60, 90, 150), Skin = rgb(234, 184, 146), Hat = true },
		{ Shirt = rgb(84, 140, 200), Pants = rgb(96, 74, 56), Skin = rgb(160, 110, 80), Hat = false },
		{ Shirt = rgb(240, 196, 80), Pants = rgb(70, 76, 90), Skin = rgb(244, 206, 170), Hat = true },
		{ Shirt = rgb(110, 170, 96), Pants = rgb(60, 90, 150), Skin = rgb(120, 84, 62), Hat = false },
	},
	Animations = { Walk = "rbxassetid://507777826", Idle = "rbxassetid://507766388" }, -- Roblox's default R15 set
}

return HayYard
