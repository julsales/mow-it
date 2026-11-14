--!strict
-- Map building blocks, shared by every map builder (MapService for the
-- land, GrayboxService for the lobby). One place per prop: a new prop is a
-- new entry in Props.Kinds, then layouts reference it by name from
-- Shared/Config/MapLayout.luau (AGENTS.md "Code rules").
--
-- Every prop builder works in a local frame `cf` whose origin is on the
-- ground and whose +Z is the prop's "front" (doors, counters, signs).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Props = {}

-- Smooth terrain draws the top of a full voxel layer [-4, 0] at y = 2
-- (surfaces sit mid-voxel), so the ground is at 2 and everything stands on it.
local GROUND_TOP = 2
local RAD45 = math.rad(45)
local RAD90 = math.rad(90)
Props.GroundTop = GROUND_TOP

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

local function bush(parent: Instance, cf: CFrame, x: number, z: number, scale: number?)
	local s = scale or 1
	local m = model("Bush", parent)
	ball("Leaves", m, cf, 4.2 * s, x, 1.4 * s, z, COLORS.Leaves, Enum.Material.Grass)
	ball("Leaves", m, cf, 3.2 * s, x + 1.6 * s, 1.1 * s, z + 0.6 * s, COLORS.DarkLeaves, Enum.Material.Grass)
	ball("Leaves", m, cf, 2.8 * s, x - 1.4 * s, 1 * s, z - 0.7 * s, COLORS.DarkLeaves, Enum.Material.Grass)
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
local function shop(parent: Instance, cf: CFrame, x: number, z: number, accent: Color3, title: string?): Model
	local m = model("ShopStall", parent)
	box("Counter", m, cf, Vector3.new(12, 3.2, 2.5), x, z + 2, COLORS.Wood, Enum.Material.WoodPlanks)
	box("Awning", m, cf, Vector3.new(14, 0.4, 7), x, z + 1, accent, nil, 8)
	for _, dx in { -6.6, 6.6 } do
		box("Post", m, cf, Vector3.new(0.6, 8, 0.6), x + dx, z - 2.2, COLORS.DarkWood, Enum.Material.Wood)
	end
	local board = box("Sign", m, cf, Vector3.new(10, 2.4, 0.4), x, z + 1, COLORS.White, nil, 8.4)
	label(board, Enum.NormalId.Back, title or "SHOP")
	return m
end

-- A farmer NPC (default R15 body, colored clothes, a straw hat built from
-- parts) standing still, e.g. behind a FarmerStand counter. No dialog.
local function npc(parent: Instance, at: CFrame, title: string, shirt: Color3)
	task.spawn(function()
		local description = Instance.new("HumanoidDescription")
		local skin = Color3.fromRGB(234, 184, 146)
		description.HeadColor = skin
		description.LeftArmColor = skin
		description.RightArmColor = skin
		description.TorsoColor = shirt
		description.LeftLegColor = Color3.fromRGB(60, 90, 150) -- jeans
		description.RightLegColor = Color3.fromRGB(60, 90, 150)
		local ok, npc = pcall(function()
			return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
		end)
		if not ok or not npc then
			warn("[MowIt][Map] Could not build the NPC:", npc)
			return
		end
		npc.Name = "Npc"
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
		text.Text = title
		text.Parent = tag
		tag.Parent = head
		npc.Parent = parent
	end)
end

-- Market stall behind the sell pad: counter with grass bales, striped
-- awning and a "SELL GRASS" board (no NPC: stepping on the pad sells).
-- Local -Z is away from the lawn, so the stall sits behind the pad.
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
	label(board, Enum.NormalId.Back, "SELL GRASS", Color3.fromRGB(90, 60, 0))
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
		-- Leafy bushes with small flowers on top (big round "flowers" read
		-- as balls/eggs).
		for j = 1, 4 do
			local fx = x + dx - 2.25 + (j - 1) * 1.5
			local leaves = ball("Leaves", m, cf, 1.3, fx, 1.5, z, COLORS.Leaves, Enum.Material.Grass)
			leaves.CanCollide = false
			for k = 0, 2 do
				local a = (j * 2 + k) * 2.1
				local flower = ball("Flower", m, cf, 0.38, fx + math.cos(a) * 0.4, 2.1 + (k % 2) * 0.12, z + math.sin(a) * 0.4, flowerColors[(i + j + k) % #flowerColors + 1])
				flower.CanCollide = false
			end
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

-- Registry ------------------------------------------------------------------------
-- Name -> builder at the frame origin, plus a footprint radius (studs) so
-- layouts can keep props apart and off the lawns.
export type Kind = { Radius: number, Build: (parent: Instance, cf: CFrame) -> () }

local function kind(radius: number, build: (Instance, CFrame) -> ()): Kind
	return { Radius = radius, Build = build }
end

-- Prop library: audited Creator Store models (docs/ASSETS.md) saved in the
-- place under ServerStorage/MapProps/<KindName>/ (one or more variant
-- models). When a kind has library models, they replace the Part-built
-- fallback below. Optional attribute `Scale` on a variant = its base scale.
local function libraryVariants(name: string): { Model }
	local library = ServerStorage:FindFirstChild("MapProps")
	local folder = library and library:FindFirstChild(name)
	local variants = {}
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") then
				table.insert(variants, child)
			end
		end
	end
	return variants
end

-- Places a library model with its footprint centered on `cf` and its
-- bottom on cf's height. Returns nil when the kind has no library models.
function Props.fromLibrary(name: string, parent: Instance, cf: CFrame, scale: number?): Model?
	local variants = libraryVariants(name)
	if #variants == 0 then
		return nil
	end
	local p = cf.Position
	local pick = Random.new(math.floor(p.X * 7.3) * 92821 + math.floor(p.Z * 3.1)):NextInteger(1, #variants)
	local m = variants[pick]:Clone()
	local base = m:GetAttribute("Scale")
	local factor = (if type(base) == "number" then base else 1) * (scale or 1)
	if math.abs(factor - 1) > 0.01 then
		m:ScaleTo(m:GetScale() * factor)
	end
	m:PivotTo(cf)
	local box, size = m:GetBoundingBox()
	local bottom = Vector3.new(box.X, box.Y - size.Y / 2, box.Z)
	m:PivotTo(cf + (p - bottom))
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	m.Parent = parent
	return m
end

-- Small scattered things (trees, bushes, rocks) by name, with a scale:
-- library model if there is one, else the Part-built look.
local scatter: { [string]: (Instance, CFrame, number) -> () } = {
	Tree = function(parent, cf, scale)
		tree(parent, cf, 0, 0, scale)
	end,
	Bush = function(parent, cf, scale)
		bush(parent, cf, 0, 0, scale)
	end,
	Rock = function(parent, cf, scale)
		ball("Rock", model("Rock", parent), cf, 3 * scale, 0, 0.6 * scale, 0, COLORS.Curb, Enum.Material.Slate)
	end,
}
function Props.place(name: string, parent: Instance, cf: CFrame, scale: number)
	if not Props.fromLibrary(name, parent, cf, scale) then
		local build = scatter[name]
		if build then
			build(parent, cf, scale)
		end
	end
end

Props.Kinds = {
	Tree = kind(5, function(p, cf)
		tree(p, cf, 0, 0, 0.8 + math.random() * 0.5)
	end),
	House = kind(18, function(p, cf)
		gable(model("House", p), cf, 0, 0, 30, 12, 20, COLORS.Cream, COLORS.Roof, nil, Enum.Material.Brick)
	end),
	Shed = kind(8, function(p, cf)
		gable(model("Shed", p), cf, 0, 0, 10, 7, 8, COLORS.Wood, COLORS.DarkLeaves, Vector2.new(3.5, 5.5), Enum.Material.WoodPlanks)
	end),
	Barn = kind(15, function(p, cf)
		gable(model("Barn", p), cf, 0, 0, 24, 12, 20, COLORS.BarnRed, COLORS.DarkRoof, Vector2.new(8, 9), Enum.Material.WoodPlanks)
	end),
	RanchHouse = kind(18, function(p, cf)
		gable(model("RanchHouse", p), cf, 0, 0, 32, 9, 14, COLORS.Wood, COLORS.DarkWood, nil, Enum.Material.WoodPlanks)
	end),
	Hangar = kind(22, function(p, cf)
		gable(model("Hangar", p), cf, 0, 0, 40, 12, 24, COLORS.Metal, COLORS.DarkRoof, Vector2.new(14, 10), Enum.Material.CorrodedMetal)
	end),
	Pond = kind(8, function(p, cf)
		pond(p, cf, 0, 0)
	end),
	Planters = kind(8, function(p, cf)
		planters(p, cf, 0, 0)
	end),
	Mailbox = kind(2, function(p, cf)
		local m = model("Mailbox", p)
		box("Post", m, cf, Vector3.new(0.4, 3.6, 0.4), 0, 0, COLORS.DarkWood, Enum.Material.Wood)
		local b = box("Box", m, cf, Vector3.new(1.2, 1.1, 1.9), 0, 0, Color3.fromRGB(70, 120, 190), Enum.Material.Metal, 3.6)
		b.Shape = Enum.PartType.Block
		box("Flag", m, cf, Vector3.new(0.1, 0.9, 0.3), 0.65, -0.4, COLORS.BarnRed, nil, 4.1)
	end),
	Hay = kind(8, function(p, cf)
		hay(p, cf, 0, 0)
	end),
	Silo = kind(6, function(p, cf)
		silo(p, cf, 0, 0)
	end),
	TallSilo = kind(6, function(p, cf)
		silo(p, cf, 0, 0, 26)
	end),
	WaterTower = kind(8, function(p, cf)
		waterTower(p, cf, 0, 0)
	end),
	PuttingGreen = kind(11, function(p, cf)
		puttingGreen(p, cf, 0, 0)
	end),
	Bunker = kind(6, function(p, cf)
		bunker(p, cf, 0, 0)
	end),
	Mansion = kind(24, function(p, cf)
		mansion(p, cf, 0, 0)
	end),
	Turbine = kind(8, function(p, cf)
		turbine(p, cf, 0, 0)
	end),
}

-- Library models replace the Part-built kinds that have them.
for name, k in Props.Kinds do
	local build = k.Build
	k.Build = function(parent: Instance, cf: CFrame)
		if not Props.fromLibrary(name, parent, cf) then
			build(parent, cf)
		end
	end
end

-- An arch over a bridge gate: two posts, a beam and the area's name.
function Props.gateArch(parent: Instance, frame: CFrame, width: number, height: number, title: string, accent: Color3)
	local m = model("GateArch", parent)
	local postH = height + 2
	for _, side in { -1, 1 } do
		make("ArchPost", m, {
			Size = Vector3.new(1.4, postH, 1.4),
			CFrame = frame * CFrame.new(side * (width / 2 + 0.4), postH / 2, 0),
			Color = COLORS.DarkWood,
			Material = Enum.Material.Wood,
		})
		make("ArchCap", m, {
			Size = Vector3.new(1.9, 0.6, 1.9),
			CFrame = frame * CFrame.new(side * (width / 2 + 0.4), postH + 0.3, 0),
			Color = accent,
			Material = Enum.Material.Wood,
		})
	end
	-- Deeper than the posts, so the posts never cover the ends of the name.
	local beam = make("ArchBeam", m, {
		Size = Vector3.new(width + 3.4, 2.2, 1.8),
		CFrame = frame * CFrame.new(0, postH - 1.4, 0),
		Color = COLORS.Wood,
		Material = Enum.Material.WoodPlanks,
	})
	label(beam, Enum.NormalId.Front, title)
	label(beam, Enum.NormalId.Back, title)
	make("ArchStripe", m, {
		Size = Vector3.new(width + 3.6, 0.35, 1.9),
		CFrame = frame * CFrame.new(0, postH - 0.15, 0),
		Color = accent,
	})
	return m
end

-- Flat look: these base materials get a texture-less MaterialVariant
-- (MaterialService override), so terrain and parts render as clean flat
-- color, matching the low-poly props instead of Roblox's stock textures.
local FLAT_MATERIALS = {
	Enum.Material.Grass, -- uncut lawn
	Enum.Material.LeafyGrass, -- wild ground
	Enum.Material.Ground, -- mowed stripe, dirt paths
	Enum.Material.Mud, -- mowed stripe
	Enum.Material.Sand,
	Enum.Material.Rock,
	Enum.Material.Slate,
	Enum.Material.Cobblestone,
	Enum.Material.Wood,
	Enum.Material.WoodPlanks,
	Enum.Material.Brick,
	Enum.Material.Fabric,
}

function Props.UseFlatMaterials()
	local MaterialService = game:GetService("MaterialService")
	local folder = MaterialService:FindFirstChild("MowItFlat")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "MowItFlat"
		folder.Parent = MaterialService
	end
	for _, material in FLAT_MATERIALS do
		local name = "Flat" .. material.Name
		if not folder:FindFirstChild(name) then
			local variant = Instance.new("MaterialVariant")
			variant.Name = name
			variant.BaseMaterial = material
			variant.Parent = folder
		end
		-- Only when nobody chose another override in Studio.
		if MaterialService:GetBaseMaterialOverride(material) == "" then
			MaterialService:SetBaseMaterialOverride(material, name)
		end
	end
end

-- Terrain and water colors (saved with a baked map; tune them in Studio
-- under Terrain > MaterialColors and they stay). One warm, saturated
-- cartoon palette for every island.
function Props.PaintTerrain(terrain: Terrain)
	Props.UseFlatMaterials()
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(88, 150, 62)) -- wild ground
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(104, 178, 64)) -- uncut lawn
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(156, 210, 96)) -- mowed stripe
	terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(124, 188, 76)) -- mowed stripe
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(240, 218, 160)) -- beaches
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(150, 140, 128)) -- cliffs, sea rocks
	terrain.WaterColor = Color3.fromRGB(40, 170, 196)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.5
	terrain.WaterWaveSize = 0.15
	terrain.WaterWaveSpeed = 9
end

Props.Colors = COLORS
Props.make = make
Props.at = at
Props.box = box
Props.column = column
Props.disc = disc
Props.ball = ball
Props.label = label
Props.model = model
Props.gable = gable
Props.tree = tree
Props.sign = sign
Props.shop = shop
Props.sellPad = sellPad
Props.npc = npc
Props.planters = planters

-- Late summer afternoon: low warm sun, long soft shadows, warm haze, a
-- little bloom and sun rays (roblox-world-building: Lighting children).
-- Idempotent: reuses effects that already exist in the place.
local function effect(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created
end

function Props.BuildAmbience()
	-- Applied once; after that the place's own Lighting wins (hand-tuned in
	-- Studio). Delete the attribute to re-apply the defaults.
	if Lighting:GetAttribute("MowItLighting") then
		return
	end
	Lighting:SetAttribute("MowItLighting", true)
	Lighting.ClockTime = 17.3
	Lighting.GeographicLatitude = 38
	Lighting.Brightness = 2.4
	Lighting.ExposureCompensation = 0.15
	Lighting.Ambient = Color3.fromRGB(96, 84, 72)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 132, 112)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	pcall(function()
		(Lighting :: any).LightingStyle = Enum.LightingStyle.Soft
	end)

	local atmosphere = effect("Atmosphere", "Atmosphere") :: Atmosphere
	-- Thick enough that the far sea melts into the sky (no visible map edge).
	atmosphere.Density = 0.45
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(255, 214, 172)
	atmosphere.Decay = Color3.fromRGB(176, 120, 96)
	atmosphere.Glare = 0.35
	atmosphere.Haze = 2.2

	local grading = effect("ColorCorrectionEffect", "WarmGrade") :: ColorCorrectionEffect
	grading.Saturation = 0.15
	grading.Contrast = 0.08
	grading.Brightness = 0.02
	grading.TintColor = Color3.fromRGB(255, 242, 226)

	local bloom = effect("BloomEffect", "SoftBloom") :: BloomEffect
	bloom.Intensity = 0.35
	bloom.Size = 28
	bloom.Threshold = 1.6

	local rays = effect("SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Intensity = 0.05
	rays.Spread = 0.6
end

return Props
