--!strict
-- GRAYBOX ONLY — delete/replace as the real maps are built in Studio.
-- If the map contract instances are missing, this builds a placeholder
-- land out of plain parts so a brand-new place is playable end-to-end
-- before any builder work. Nothing here is final art; contract pieces keep
-- their contract names (GrassArea, SellPad, ZoneGate, JoinPad, spawns) so
-- builders can replace everything else freely (docs/ARCHITECTURE.md).
--
-- Layout (top view, +Z = "front", 1 cell = 100 studs). The house sits in
-- the middle and the expansions wrap around it in unlock order, clockwise:
--
--        x: -150      -50       50       150
--   z -150  +---------+---------+---------+
--           |  Mega   | Backyard|  Sunny  |
--           |  Fields |  Garden |  Farm   |
--   z  -50  |         +---------+---------+
--           |         |  HOUSE  |   Big   |
--           |         | (Front  |  Ranch  |
--   z   50  +---------+  Yard)--+         |
--           |     Golf Estate   |         |
--   z  150  +-------------------+---------+
--                                 (lobby further out in front, z > 180)
--
-- Clipping rules this file follows on purpose:
--   * Everything stands on GROUND_TOP (y = 1), never on y = 0, so nothing
--     shares a surface with the default Studio Baseplate (z-fighting).
--   * Two parts never share a visible face: flat things are stacked on top
--     of each other (bottom = top of the thing below), never coplanar.
--   * Each zone has a grass rectangle and a separate "strip" for props, so
--     tufts never grow inside buildings, shops or pads.
--   * Fence posts are de-duplicated where fences meet.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Format)

local GrayboxService = {}

local GROUND_TOP = 1
local LAND_HALF = 150 -- land is 300 x 300, fenced
local GROUND_HALF = 172 -- ground slab reaches past the fence for a tree border
local LOBBY_CENTER = Vector3.new(0, 0, 230)
local RAD45 = math.rad(45)
local RAD90 = math.rad(90)

local COLORS = {
	Ground = Color3.fromRGB(86, 138, 66),
	Path = Color3.fromRGB(214, 206, 188),
	Road = Color3.fromRGB(66, 68, 74),
	RoadLine = Color3.fromRGB(242, 214, 110),
	Wood = Color3.fromRGB(196, 150, 102),
	DarkWood = Color3.fromRGB(112, 78, 50),
	Fence = Color3.fromRGB(245, 242, 232),
	White = Color3.fromRGB(244, 241, 232),
	Cream = Color3.fromRGB(246, 226, 180),
	Roof = Color3.fromRGB(168, 72, 60),
	DarkRoof = Color3.fromRGB(74, 78, 90),
	Leaves = Color3.fromRGB(70, 150, 74),
	DarkLeaves = Color3.fromRGB(48, 118, 60),
	Trunk = Color3.fromRGB(112, 82, 54),
	Water = Color3.fromRGB(84, 168, 224),
	Sand = Color3.fromRGB(234, 214, 158),
	Hay = Color3.fromRGB(228, 196, 96),
	Metal = Color3.fromRGB(176, 182, 190),
	BarnRed = Color3.fromRGB(180, 56, 48),
	Window = Color3.fromRGB(150, 206, 240),
	Door = Color3.fromRGB(122, 84, 56),
	Sell = Color3.fromRGB(255, 200, 50),
	Text = Color3.fromRGB(40, 40, 40),
	Curb = Color3.fromRGB(150, 140, 124),
	Green = Color3.fromRGB(128, 210, 110),
}

-- Primitive helpers ----------------------------------------------------------

type PartSpec = {
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	Transparency: number?,
	Solid: boolean?, -- false = decorative, players walk through it
}

local function make(name: string, parent: Instance, spec: PartSpec): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if spec.Shape then
		part.Shape = spec.Shape -- before Size: Ball forces a uniform size
	end
	part.Size = spec.Size
	part.CFrame = spec.CFrame
	part.Color = spec.Color
	part.Material = spec.Material or Enum.Material.SmoothPlastic
	part.Transparency = spec.Transparency or 0
	if spec.Solid == false then
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
	end
	part.Parent = parent
	return part
end

-- Every prop builder works in a local frame `cf` whose origin is on the
-- ground and whose +Z points at the zone's grass ("the front").
local function at(cf: CFrame, x: number, y: number, z: number): CFrame
	return cf * CFrame.new(x, y, z)
end

local function box(name: string, parent: Instance, cf: CFrame, size: Vector3, x: number, z: number, color: Color3, material: Enum.Material?, lift: number?): Part
	return make(name, parent, {
		Size = size,
		CFrame = at(cf, x, (lift or 0) + size.Y / 2, z),
		Color = color,
		Material = material,
	})
end

-- Upright cylinder (Roblox cylinders run along X, so tip it 90 degrees).
local function column(name: string, parent: Instance, cf: CFrame, height: number, diameter: number, x: number, z: number, color: Color3, material: Enum.Material?, lift: number?): Part
	return make(name, parent, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = at(cf, x, (lift or 0) + height / 2, z) * CFrame.Angles(0, 0, RAD90),
		Color = color,
		Material = material,
	})
end

local function disc(name: string, parent: Instance, cf: CFrame, diameter: number, thickness: number, x: number, z: number, color: Color3, material: Enum.Material?, lift: number?): Part
	local part = column(name, parent, cf, thickness, diameter, x, z, color, material, lift)
	return part
end

local function ball(name: string, parent: Instance, cf: CFrame, diameter: number, x: number, y: number, z: number, color: Color3, material: Enum.Material?): Part
	return make(name, parent, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * diameter,
		CFrame = at(cf, x, y, z),
		Color = color,
		Material = material,
	})
end

local function label(part: BasePart, face: Enum.NormalId, text: string, textColor: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextScaled = true
	textLabel.TextColor3 = textColor or COLORS.Text
	textLabel.Text = text
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.1, 0)
	padding.PaddingBottom = UDim.new(0.1, 0)
	padding.Parent = textLabel
	textLabel.Parent = gui
	gui.Parent = part
end

local function model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Prop builders (local frame, see `at`) -------------------------------------

-- House-like building with a 45-degree gable roof. The attic is a square
-- prism turned 45 degrees: its top half is exactly the gable triangle, its
-- bottom half hides inside the walls. Roof slabs sit just above its faces.
local function gable(parent: Instance, cf: CFrame, x: number, z: number, w: number, h: number, d: number, walls: Color3, roof: Color3, door: Vector2?, wallMaterial: Enum.Material?)
	box("Walls", parent, cf, Vector3.new(w, h, d), x, z, walls, wallMaterial)
	local side = d / math.sqrt(2)
	make("Attic", parent, {
		Size = Vector3.new(w, side, side),
		CFrame = at(cf, x, h, z) * CFrame.Angles(RAD45, 0, 0),
		Color = walls,
		Material = wallMaterial,
	})
	local slabLength = (d / 2 + 1) * math.sqrt(2)
	for _, dir in { 1, -1 } do
		local normal = Vector3.new(0, math.cos(RAD45), dir * math.sin(RAD45)) * 0.45
		local mid = Vector3.new(x, h + (d / 2 - 1) / 2, z + dir * (d / 2 + 1) / 2) + normal
		make("Roof", parent, {
			Size = Vector3.new(w + 2, 0.8, slabLength),
			CFrame = at(cf, mid.X, mid.Y, mid.Z) * CFrame.Angles(dir * RAD45, 0, 0),
			Color = roof,
		})
	end
	local doorSize = door or Vector2.new(4.5, 7.5)
	box("Door", parent, cf, Vector3.new(doorSize.X, doorSize.Y, 0.3), x, z + d / 2 + 0.15, COLORS.Door)
	if w >= 16 and h >= 7 then
		for _, dx in { -w / 4 - 1, w / 4 + 1 } do
			make("Window", parent, {
				Size = Vector3.new(4, 3.5, 0.3),
				CFrame = at(cf, x + dx, h * 0.55, z + d / 2 + 0.15),
				Color = COLORS.Window,
				Material = Enum.Material.Glass,
				Transparency = 0.2,
			})
		end
	end
end

local function tree(parent: Instance, cf: CFrame, x: number, z: number, scale: number?)
	local s = scale or 1
	local m = model("Tree", parent)
	column("Trunk", m, cf, 7 * s, 1.6 * s, x, z, COLORS.Trunk, Enum.Material.Wood)
	ball("Leaves", m, cf, 9 * s, x, 9 * s, z, COLORS.Leaves, Enum.Material.Grass)
	ball("Leaves", m, cf, 6 * s, x + 2.2 * s, 11.5 * s, z - 1 * s, COLORS.DarkLeaves, Enum.Material.Grass)
end

local function sign(parent: Instance, cf: CFrame, x: number, z: number, text: string, accent: Color3)
	local m = model("ZoneSign", parent)
	local board = box("Board", m, cf, Vector3.new(16, 5, 0.5), x, z, COLORS.White, nil, 3)
	box("Stripe", m, cf, Vector3.new(16, 0.6, 0.6), x, z, accent, nil, 8)
	label(board, Enum.NormalId.Back, text)
	for _, dx in { -7, 7 } do
		box("Post", m, cf, Vector3.new(0.6, 8, 0.6), x + dx, z - 0.6, COLORS.DarkWood, Enum.Material.Wood)
	end
end

-- Physical shop stall (spec: each expansion has its own physical shop).
local function shop(parent: Instance, cf: CFrame, x: number, z: number, accent: Color3)
	local m = model("ShopStall", parent)
	box("Counter", m, cf, Vector3.new(12, 3.2, 2.5), x, z + 2, COLORS.Wood, Enum.Material.WoodPlanks)
	box("Awning", m, cf, Vector3.new(14, 0.4, 7), x, z + 1, accent, nil, 8)
	for _, dx in { -6.6, 6.6 } do
		box("Post", m, cf, Vector3.new(0.6, 8, 0.6), x + dx, z - 2.2, COLORS.DarkWood, Enum.Material.Wood)
	end
	local board = box("Sign", m, cf, Vector3.new(10, 2.4, 0.4), x, z + 1, COLORS.White, nil, 8.4)
	label(board, Enum.NormalId.Back, "SHOP")
end

-- The grass buyer: a farmer NPC (default R15 body, colored clothes, a
-- straw hat built from parts) standing still behind the stall counter.
-- No dialog: stepping on the pad sells instantly, he is the face of it.
local function buyerNpc(parent: Instance, at: CFrame)
	task.spawn(function()
		local description = Instance.new("HumanoidDescription")
		local skin = Color3.fromRGB(234, 184, 146)
		description.HeadColor = skin
		description.LeftArmColor = skin
		description.RightArmColor = skin
		description.TorsoColor = Color3.fromRGB(196, 64, 52) -- red plaid shirt
		description.LeftLegColor = Color3.fromRGB(60, 90, 150) -- jeans
		description.RightLegColor = Color3.fromRGB(60, 90, 150)
		local ok, npc = pcall(function()
			return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
		end)
		if not ok or not npc then
			warn("[MowIt][Graybox] Could not build the grass buyer NPC:", npc)
			return
		end
		npc.Name = "GrassBuyer"
		local humanoid = npc:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart
		root.Anchored = true
		npc:PivotTo(at * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))

		local head = npc:FindFirstChild("Head") :: BasePart
		local straw = Color3.fromRGB(226, 196, 120)
		for i, spec in { { size = Vector3.new(0.12, 2.4, 2.4), y = 0.55 }, { size = Vector3.new(0.9, 1.25, 1.25), y = 0.95 } } do
			local piece = Instance.new("Part")
			piece.Name = if i == 1 then "HatBrim" else "HatTop"
			piece.Shape = Enum.PartType.Cylinder
			piece.Size = spec.size
			piece.Color = straw
			piece.Material = Enum.Material.Fabric
			piece.CanCollide = false
			piece.Massless = true
			piece.CFrame = head.CFrame * CFrame.new(0, spec.y, 0) * CFrame.Angles(0, 0, RAD90)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = piece
			weld.Parent = piece
			piece.Parent = npc
		end

		local tag = Instance.new("BillboardGui")
		tag.Name = "NameTag"
		tag.Size = UDim2.fromOffset(160, 36)
		tag.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
		tag.MaxDistance = 45
		tag.LightInfluence = 0
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.3
		text.Text = "Seu Zé · compra grama"
		text.Parent = tag
		tag.Parent = head
		npc.Parent = parent
	end)
end

-- Market stall behind the sell pad: counter with grass bales, striped
-- awning, a "COMPRO GRAMA" board and the buyer NPC. Local -Z is away from
-- the lawn, so the stall sits behind the pad facing the player.
local function sellStall(parent: Instance, cf: CFrame, x: number, z: number)
	local m = model("SellStall", parent)
	local back = z - 7.5
	box("Counter", m, cf, Vector3.new(9, 3.2, 2), x, back + 1.2, COLORS.Wood, Enum.Material.WoodPlanks)
	for _, dx in { -2.6, 0, 2.6 } do
		box("GrassBale", m, cf, Vector3.new(1.8, 1.1, 1.3), x + dx, back + 1.2, Color3.fromRGB(110, 170, 70), Enum.Material.Grass, 3.2)
	end
	for _, dx in { -4.2, 4.2 } do
		for _, dz in { -1, 2.2 } do
			box("Post", m, cf, Vector3.new(0.4, 7.5, 0.4), x + dx, back + dz, COLORS.DarkWood, Enum.Material.Wood)
		end
	end
	for i = 0, 5 do
		local color = if i % 2 == 0 then COLORS.Sell else COLORS.White
		box("Awning", m, cf, Vector3.new(1.55, 0.35, 4.2), x - 3.9 + i * 1.55, back + 0.6, color, Enum.Material.Fabric, 7.5)
	end
	local board = box("Board", m, cf, Vector3.new(7, 1.6, 0.3), x, back + 2.75, COLORS.White, nil, 7.9)
	label(board, Enum.NormalId.Back, "COMPRO GRAMA", Color3.fromRGB(90, 60, 0))
	buyerNpc(m, at(cf, x, 0, back - 1) * CFrame.Angles(0, math.pi, 0))
end

local function sellPad(parent: Instance, cf: CFrame, x: number, z: number)
	-- Contract part: must be called "SellPad" (EconomyService finds it by name).
	local pad = box("SellPad", parent, cf, Vector3.new(10, 0.4, 10), x, z, COLORS.Sell, Enum.Material.Neon)
	label(pad, Enum.NormalId.Top, "SELL", Color3.fromRGB(90, 60, 0))
	sellStall(parent, cf, x, z)
end

local function pond(parent: Instance, cf: CFrame, x: number, z: number)
	local m = model("Pond", parent)
	disc("Rim", m, cf, 13, 0.3, x, z, COLORS.Curb, Enum.Material.Slate)
	disc("Water", m, cf, 11, 0.2, x, z, COLORS.Water, Enum.Material.Glass, 0.3)
end

local function planters(parent: Instance, cf: CFrame, x: number, z: number)
	local m = model("FlowerBeds", parent)
	local flowerColors = {
		Color3.fromRGB(236, 84, 104),
		Color3.fromRGB(250, 214, 70),
		Color3.fromRGB(196, 120, 230),
		Color3.fromRGB(255, 160, 200),
	}
	for i, dx in { -3.5, 3.5 } do
		box("Planter", m, cf, Vector3.new(6, 1.2, 3), x + dx, z, COLORS.DarkWood, Enum.Material.WoodPlanks)
		for j = 1, 4 do
			local color = flowerColors[(i + j) % #flowerColors + 1]
			local flower = ball("Flower", m, cf, 1.2, x + dx - 2.25 + (j - 1) * 1.5, 1.8, z, color)
			flower.CanCollide = false
		end
	end
end

local function hay(parent: Instance, cf: CFrame, x: number, z: number)
	local m = model("HayBales", parent)
	for _, dx in { -4.5, 0, 4.5 } do
		make("Bale", m, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4, 3.6, 3.6),
			CFrame = at(cf, x + dx, 1.8, z),
			Color = COLORS.Hay,
			Material = Enum.Material.Fabric,
		})
	end
	make("Bale", m, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, 3.6, 3.6),
		CFrame = at(cf, x - 2.25, 5, z),
		Color = COLORS.Hay,
		Material = Enum.Material.Fabric,
	})
end

local function silo(parent: Instance, cf: CFrame, x: number, z: number, height: number?)
	local m = model("Silo", parent)
	local h = height or 20
	column("Body", m, cf, h, 9, x, z, COLORS.Metal, Enum.Material.DiamondPlate)
	ball("Dome", m, cf, 9, x, h, z, COLORS.DarkRoof)
end

local function waterTower(parent: Instance, cf: CFrame, x: number, z: number)
	local m = model("WaterTower", parent)
	for _, offset in { Vector2.new(-4, -4), Vector2.new(4, -4), Vector2.new(-4, 4), Vector2.new(4, 4) } do
		box("Leg", m, cf, Vector3.new(0.8, 14, 0.8), x + offset.X, z + offset.Y, COLORS.DarkWood, Enum.Material.Wood)
	end
	column("Tank", m, cf, 8, 12, x, z, COLORS.Wood, Enum.Material.WoodPlanks, 14)
end

local function puttingGreen(parent: Instance, cf: CFrame, x: number, z: number)
	local m = model("PuttingGreen", parent)
	disc("Green", m, cf, 20, 0.25, x, z, COLORS.Green, Enum.Material.Grass)
	box("FlagPole", m, cf, Vector3.new(0.3, 8, 0.3), x + 3, z, COLORS.White, nil, 0.25)
	box("Flag", m, cf, Vector3.new(3, 2, 0.1), x + 4.65, z, Color3.fromRGB(230, 60, 60), nil, 6.2)
end

local function bunker(parent: Instance, cf: CFrame, x: number, z: number)
	disc("SandBunker", parent, cf, 11, 0.2, x, z, COLORS.Sand, Enum.Material.Sand)
end

local function mansion(parent: Instance, cf: CFrame, x: number, z: number)
	local m = model("Mansion", parent)
	local zc = z - 3 -- leave room for the porch in front
	gable(m, cf, x, zc, 44, 14, 18, COLORS.White, COLORS.DarkRoof, Vector2.new(6, 9), Enum.Material.Concrete)
	for _, dx in { -14, -6, 6, 14 } do
		column("Column", m, cf, 10, 1.4, x + dx, zc + 11, COLORS.White, Enum.Material.Marble)
	end
	box("Porch", m, cf, Vector3.new(32, 0.6, 5), x, zc + 11.5, COLORS.DarkRoof, nil, 10)
end

local function turbine(parent: Instance, cf: CFrame, x: number, z: number)
	local m = model("WindTurbine", parent)
	column("Tower", m, cf, 30, 2, x, z, COLORS.White)
	box("Nacelle", m, cf, Vector3.new(2.6, 2.6, 5), x, z + 0.5, COLORS.White, nil, 29.5)
	local hub = ball("Hub", m, cf, 2.4, x, 30.8, z + 3.6, COLORS.Metal)
	for i = 0, 2 do
		make("Blade", m, {
			Size = Vector3.new(1.2, 11, 0.3),
			CFrame = hub.CFrame * CFrame.Angles(0, 0, math.rad(i * 120 + 15)) * CFrame.new(0, 6.3, 0.6),
			Color = COLORS.White,
		})
	end
end

-- Zone layouts -----------------------------------------------------------------

type Rect = { X1: number, Z1: number, X2: number, Z2: number }
type Item = { Width: number, Build: (parent: Instance, cf: CFrame, x: number, z: number) -> () }
type ZoneLayout = {
	Grass: Rect,
	Strip: Rect, -- where shop / sell pad / props go, never overlapping grass
	Front: Vector3, -- direction from the strip toward the grass
	Items: { Item },
}

local function rect(x1: number, z1: number, x2: number, z2: number): Rect
	return { X1 = x1, Z1 = z1, X2 = x2, Z2 = z2 }
end

local function item(width: number, build: (Instance, CFrame, number, number) -> ()): Item
	return { Width = width, Build = build }
end

local SELL = item(10, sellPad)
local TREE = item(10, function(p, cf, x, z)
	tree(p, cf, x, z)
end)
local POND = item(14, pond)
local PLANTERS = item(14, planters)
local HAY = item(13, hay)
local SILO = item(10, function(p, cf, x, z)
	silo(p, cf, x, z)
end)
local TALL_SILO = item(10, function(p, cf, x, z)
	silo(p, cf, x, z, 26)
end)
local WATER_TOWER = item(14, waterTower)
local GREEN = item(22, puttingGreen)
local BUNKER = item(12, bunker)
local MANSION = item(44, mansion)
local TURBINE = item(14, turbine)
local HOUSE = item(30, function(p, cf, x, z)
	gable(model("House", p), cf, x, z, 30, 12, 20, COLORS.Cream, COLORS.Roof, nil, Enum.Material.Brick)
end)
local SHED = item(12, function(p, cf, x, z)
	gable(model("Shed", p), cf, x, z, 10, 7, 8, COLORS.Wood, COLORS.DarkLeaves, Vector2.new(3.5, 5.5), Enum.Material.WoodPlanks)
end)
local BARN = item(24, function(p, cf, x, z)
	gable(model("Barn", p), cf, x, z, 24, 12, 20, COLORS.BarnRed, COLORS.DarkRoof, Vector2.new(8, 9), Enum.Material.WoodPlanks)
end)
local RANCH_HOUSE = item(34, function(p, cf, x, z)
	gable(model("RanchHouse", p), cf, x, z, 32, 9, 14, COLORS.Wood, COLORS.DarkWood, nil, Enum.Material.WoodPlanks)
end)
local HANGAR = item(40, function(p, cf, x, z)
	gable(model("Hangar", p), cf, x, z, 40, 12, 24, COLORS.Metal, COLORS.DarkRoof, Vector2.new(14, 10), Enum.Material.CorrodedMetal)
end)

-- "SHOP" and "SIGN" are filled in per zone (they need the zone's accent/name).
local SHOP_MARK = item(14, function() end)
local SIGN_MARK = item(16, function() end)

local LAYOUTS: { [string]: ZoneLayout } = {
	front_yard = {
		Grass = rect(-44, -4, 44, 44),
		Strip = rect(-44, -44, 44, -10),
		Front = Vector3.new(0, 0, 1),
		Items = { SIGN_MARK, SHOP_MARK, HOUSE, SELL, TREE },
	},
	backyard = {
		Grass = rect(-44, -144, 44, -84),
		Strip = rect(-44, -80, 44, -54),
		Front = Vector3.new(0, 0, -1),
		Items = { SHOP_MARK, SELL, PLANTERS, POND, SHED, SIGN_MARK },
	},
	sunny_farm = {
		Grass = rect(56, -144, 144, -84),
		Strip = rect(56, -80, 144, -54),
		Front = Vector3.new(0, 0, -1),
		Items = { BARN, SILO, HAY, SELL, SHOP_MARK },
	},
	big_ranch = {
		Grass = rect(84, -44, 144, 144),
		Strip = rect(56, -44, 80, 144),
		Front = Vector3.new(1, 0, 0),
		Items = { TREE, TREE, HAY, WATER_TOWER, RANCH_HOUSE, SELL, SHOP_MARK, SIGN_MARK },
	},
	golf_estate = {
		Grass = rect(-144, 84, 44, 144),
		Strip = rect(-144, 56, 44, 80),
		Front = Vector3.new(0, 0, 1),
		Items = { TREE, BUNKER, GREEN, MANSION, TREE, SELL, SHOP_MARK, SIGN_MARK },
	},
	mega_fields = {
		Grass = rect(-144, -144, -84, 44),
		Strip = rect(-80, -144, -56, 44),
		Front = Vector3.new(-1, 0, 0),
		Items = { TURBINE, HANGAR, TALL_SILO, TALL_SILO, TALL_SILO, TURBINE, SELL, SHOP_MARK, SIGN_MARK },
	},
}

-- Gates sit on the fence between a zone and the one before it.
-- Axis "X" = fence runs along X at fixed Z; "Z" = runs along Z at fixed X.
type Fence = { Axis: string, Fixed: number, From: number, To: number, GateZoneId: string?, GateAt: number? }

local FENCES: { Fence } = {
	-- perimeter
	{ Axis = "X", Fixed = -LAND_HALF, From = -LAND_HALF, To = LAND_HALF },
	{ Axis = "X", Fixed = LAND_HALF, From = -LAND_HALF, To = LAND_HALF },
	{ Axis = "Z", Fixed = -LAND_HALF, From = -LAND_HALF, To = LAND_HALF },
	{ Axis = "Z", Fixed = LAND_HALF, From = -LAND_HALF, To = LAND_HALF },
	-- between zones, with a gate where the unlock order crosses
	{ Axis = "X", Fixed = -50, From = -50, To = 50, GateZoneId = "backyard", GateAt = 30 },
	{ Axis = "Z", Fixed = 50, From = -150, To = -50, GateZoneId = "sunny_farm", GateAt = -67 },
	{ Axis = "X", Fixed = -50, From = 50, To = 150, GateZoneId = "big_ranch", GateAt = 68 },
	{ Axis = "Z", Fixed = 50, From = 50, To = 150, GateZoneId = "golf_estate", GateAt = 68 },
	{ Axis = "X", Fixed = 50, From = -150, To = -50, GateZoneId = "mega_fields", GateAt = -68 },
	-- between zones, no gate
	{ Axis = "Z", Fixed = 50, From = -50, To = 50 },
	{ Axis = "X", Fixed = 50, From = -50, To = 50 },
	{ Axis = "Z", Fixed = -50, From = -50, To = 50 },
	{ Axis = "Z", Fixed = -50, From = -150, To = -50 },
}

local GATE_WIDTH = 12
local POST_SPACING = 8

local function worldPoint(axis: string, fixed: number, along: number): Vector3
	if axis == "X" then
		return Vector3.new(along, 0, fixed)
	end
	return Vector3.new(fixed, 0, along)
end

local function buildFences(parent: Instance)
	local fences = Instance.new("Folder")
	fences.Name = "Fences"
	fences.Parent = parent
	local postsAt: { [string]: boolean } = {}
	local ground = CFrame.new(0, GROUND_TOP, 0)

	local function post(point: Vector3)
		local key = ("%d,%d"):format(math.round(point.X), math.round(point.Z))
		if postsAt[key] then
			return
		end
		postsAt[key] = true
		box("Post", fences, ground, Vector3.new(0.9, 4.2, 0.9), point.X, point.Z, COLORS.Fence, Enum.Material.Wood)
	end

	local function run(axis: string, fixed: number, from: number, to: number)
		local length = to - from
		if length <= 0 then
			return
		end
		local count = math.max(1, math.round(length / POST_SPACING))
		for i = 0, count do
			post(worldPoint(axis, fixed, from + length * i / count))
		end
		local mid = worldPoint(axis, fixed, (from + to) / 2)
		local size = if axis == "X" then Vector3.new(length, 0.5, 0.3) else Vector3.new(0.3, 0.5, length)
		for _, height in { 1.5, 3.2 } do
			make("Rail", fences, {
				Size = size,
				CFrame = CFrame.new(mid.X, GROUND_TOP + height, mid.Z),
				Color = COLORS.Fence,
				Material = Enum.Material.Wood,
			})
		end
	end

	for _, fence in FENCES do
		if fence.GateZoneId and fence.GateAt then
			local gateFrom = fence.GateAt - GATE_WIDTH / 2
			local gateTo = fence.GateAt + GATE_WIDTH / 2
			run(fence.Axis, fence.Fixed, fence.From, gateFrom)
			run(fence.Axis, fence.Fixed, gateTo, fence.To)
		else
			run(fence.Axis, fence.Fixed, fence.From, fence.To)
		end
	end
end

-- The gate itself is a contract part (Zones/<id>/ZoneGate). It is solid
-- for everyone on the server; each client opens the gates of zones its
-- player has unlocked (Main.client.luau), so locked land stays closed off.
local function buildGate(fence: Fence, zoneFolder: Instance, zone)
	local center = worldPoint(fence.Axis, fence.Fixed, fence.GateAt :: number)
	local rotation = if fence.Axis == "X" then CFrame.identity else CFrame.Angles(0, RAD90, 0)
	local gate = make("ZoneGate", zoneFolder, {
		Size = Vector3.new(GATE_WIDTH, 7, 0.6),
		CFrame = CFrame.new(center.X, GROUND_TOP + 3.5, center.Z) * rotation,
		Color = zone.ThemeColor,
		Material = Enum.Material.Glass,
		Transparency = 0.3,
	})
	local text = ("LOCKED\n%s\n%s · Lv %d"):format(zone.DisplayName, Format.Coins(zone.UnlockPrice), zone.RequiredLevel)
	label(gate, Enum.NormalId.Front, text, Color3.new(1, 1, 1))
	label(gate, Enum.NormalId.Back, text, Color3.new(1, 1, 1))
end

local function lawnColor(zone): Color3
	-- The mown lawn is a lighter, slightly yellow version of the zone grass,
	-- so freshly cut patches read clearly against the tufts.
	return zone.GrassColor:Lerp(Color3.fromRGB(214, 222, 140), 0.25)
end

local function buildGrass(zoneFolder: Instance, zone, area: Rect)
	local width = area.X2 - area.X1
	local depth = area.Z2 - area.Z1
	local cx = (area.X1 + area.X2) / 2
	local cz = (area.Z1 + area.Z2) / 2
	local ground = CFrame.new(0, GROUND_TOP, 0)
	-- Contract part: GrassService spawns tufts on top of it.
	box("GrassArea", zoneFolder, ground, Vector3.new(width, 0.4, depth), cx, cz, lawnColor(zone), Enum.Material.Grass)
	local edging = model("Edging", zoneFolder)
	for _, dz in { -1, 1 } do
		box("Curb", edging, ground, Vector3.new(width + 1.2, 0.7, 0.6), cx, cz + dz * (depth / 2 + 0.3), COLORS.Curb, Enum.Material.Slate)
	end
	for _, dx in { -1, 1 } do
		box("Curb", edging, ground, Vector3.new(0.6, 0.7, depth), cx + dx * (width / 2 + 0.3), cz, COLORS.Curb, Enum.Material.Slate)
	end
end

local function buildStrip(zoneFolder: Instance, zone, layout: ZoneLayout)
	local strip = layout.Strip
	local center = Vector3.new((strip.X1 + strip.X2) / 2, GROUND_TOP, (strip.Z1 + strip.Z2) / 2)
	-- local +Z = toward the grass; local X = along the strip
	local cf = CFrame.lookAt(center, center - layout.Front)
	local alongX = layout.Front.Z ~= 0
	local length = if alongX then strip.X2 - strip.X1 else strip.Z2 - strip.Z1

	local used = 0
	for _, entry in layout.Items do
		used += entry.Width
	end
	local gap = math.max(0, (length - used) / (#layout.Items + 1))

	local dressing = model("Dressing", zoneFolder)
	local cursor = -length / 2 + gap
	for _, entry in layout.Items do
		local x = cursor + entry.Width / 2
		if entry == SHOP_MARK then
			shop(dressing, cf, x, 0, zone.ThemeColor)
		elseif entry == SIGN_MARK then
			sign(dressing, cf, x, 0, ("%s\n%s"):format(zone.DisplayName, zone.Subtitle), zone.ThemeColor)
		elseif entry == SELL then
			sellPad(zoneFolder, cf, x, 0)
		else
			entry.Build(dressing, cf, x, 0)
		end
		cursor += entry.Width + gap
	end
end

local function buildAmbience()
	if Lighting:FindFirstChildOfClass("Atmosphere") then
		return
	end
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
	pcall(function()
		(Lighting :: any).LightingStyle = Enum.LightingStyle.Soft
	end)
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(200, 220, 236)
	atmosphere.Decay = Color3.fromRGB(110, 150, 180)
	atmosphere.Glare = 0
	atmosphere.Haze = 1
	atmosphere.Parent = Lighting
end

-- Public -----------------------------------------------------------------------

function GrayboxService.BuildZonesIfMissing()
	if Workspace:FindFirstChild("Zones") then
		return
	end
	buildAmbience()

	-- The Studio "Baseplate" template ships a SpawnLocation at the origin,
	-- which now lands inside the house's lawn. Runtime only; Play mode
	-- changes are not saved to the place.
	local templateSpawn = Workspace:FindFirstChild("SpawnLocation")
	if templateSpawn and templateSpawn:IsA("SpawnLocation") then
		templateSpawn:Destroy()
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"

	local land = model("Land", Workspace)
	make("Ground", land, {
		Size = Vector3.new(GROUND_HALF * 2, 2, GROUND_HALF * 2),
		CFrame = CFrame.new(0, GROUND_TOP - 1, 0),
		Color = COLORS.Ground,
		Material = Enum.Material.Grass,
	})
	buildFences(land)
	local border = model("TreeBorder", land)
	local ground = CFrame.new(0, GROUND_TOP, 0)
	for t = -LAND_HALF, LAND_HALF, 25 do
		local jitter = (t % 50 == 0) and 0.9 or 1.15
		tree(border, ground, t, -LAND_HALF - 11, jitter)
		tree(border, ground, t, LAND_HALF + 11, jitter)
		tree(border, ground, -LAND_HALF - 11, t, jitter)
		tree(border, ground, LAND_HALF + 11, t, jitter)
	end

	for _, zone in Zones.List do
		local folder = Instance.new("Folder")
		folder.Name = zone.Id
		folder.Parent = zonesFolder
		local layout = LAYOUTS[zone.Id]
		if not layout then
			warn(("[MowIt][Graybox] No graybox layout for zone %q — build it in Studio."):format(zone.Id))
			continue
		end
		buildGrass(folder, zone, layout.Grass)
		buildStrip(folder, zone, layout)
		for _, fence in FENCES do
			if fence.GateZoneId == zone.Id then
				buildGate(fence, folder, zone)
			end
		end
	end
	zonesFolder.Parent = Workspace

	-- In front of the house, between the porch and the lawn.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "GameSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.Position = Vector3.new(0, GROUND_TOP + 0.2, -8)
	spawn.Color = COLORS.Path
	spawn.Material = Enum.Material.Concrete
	spawn.Duration = 0
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = Workspace
end

function GrayboxService.BuildLobbyIfMissing()
	if Workspace:FindFirstChild("Lobby") then
		return
	end
	buildAmbience()
	-- In Studio both places are built in one world. The lobby then sits
	-- across the street in front of the land; outside Studio it's alone.
	local landExists = Workspace:FindFirstChild("Zones") ~= nil

	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	local c = LOBBY_CENTER
	local ground = CFrame.new(c.X, GROUND_TOP, c.Z)

	make("Plaza", lobby, {
		Size = Vector3.new(160, 2, 90),
		CFrame = CFrame.new(c.X, GROUND_TOP - 1, c.Z),
		Color = COLORS.Path,
		Material = Enum.Material.Pavement,
	})
	-- The street, along the land side of the plaza.
	box("Street", lobby, ground, Vector3.new(160, 0.2, 14), 0, -36, COLORS.Road, Enum.Material.Asphalt)
	box("StreetLine", lobby, ground, Vector3.new(150, 0.05, 0.5), 0, -36, COLORS.RoadLine, nil, 0.2)

	local pad = box("JoinPad", lobby, ground, Vector3.new(14, 0.6, 14), 0, -12, Color3.fromRGB(70, 200, 120), Enum.Material.Neon)
	label(pad, Enum.NormalId.Top, "PLAY\n(party up to 4)", Color3.fromRGB(10, 60, 30))

	-- Showcase lots (spec: lobby-showcase-and-party). Empty placeholders.
	for i, x in { -60, -36, 36, 60 } do
		local lot = box("ShowcaseLot" .. i, lobby, ground, Vector3.new(18, 0.3, 18), x, 4, Color3.fromRGB(150, 196, 110), Enum.Material.Grass)
		label(lot, Enum.NormalId.Top, "SHOWCASE\n(soon)", Color3.fromRGB(40, 70, 30))
	end

	local market = model("CrewMarket", lobby)
	local marketFrame = ground * CFrame.new(0, 0, 30) * CFrame.Angles(0, math.rad(180), 0)
	gable(market, marketFrame, 0, 0, 30, 10, 14, Color3.fromRGB(250, 236, 200), Color3.fromRGB(70, 150, 120), Vector2.new(6, 8))
	sign(market, marketFrame, -12, 12, "CREW MARKET\n(soon)", Color3.fromRGB(70, 150, 120))

	for _, x in { -76, 76 } do
		for _, z in { -24, 34 } do
			tree(lobby, ground, x, z, 0.9)
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.Position = Vector3.new(c.X, GROUND_TOP + 0.2, c.Z + 10)
	spawn.Color = COLORS.White
	spawn.Material = Enum.Material.Concrete
	spawn.Duration = 0
	-- Studio combined mode: always start on the land (that's what Play is
	-- for most of the time). To playtest the queue pad in Studio, enable
	-- LobbySpawn (or disable GameSpawn) in the Explorer while playing.
	spawn.Enabled = not landExists
	spawn.Parent = lobby

	lobby.Parent = Workspace
end

return GrayboxService
