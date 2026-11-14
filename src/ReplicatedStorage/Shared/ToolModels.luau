--!strict
-- 3D models for the tool ladder. Where each look comes from, first match:
--   1. ReplicatedStorage/Assets/Tools/<ToolId> (repo assets/Tools/*.rbxm):
--      a hand-made model for one tool (assets/README.md).
--   2. The low-poly Blender art (art/tools/, Config/ToolArt): 15 base
--      meshes loaded at startup by ToolArtService into
--      ReplicatedStorage/ToolArt, painted and sized per tool.
--   3. ServerStorage/ToolOverrides/<ToolId> (legacy place-file models).
--   4. Placeholder shapes built from Parts below (when the art isn't
--      uploaded or failed to load), so the game always runs.
--
-- Model contract (what ToolVisualService and the client rely on):
--   * PrimaryPart "Root": for hand kinds = the grip; for ground kinds = a
--     point on the ground right under the player's HumanoidRootPart.
--   * Front of the model is -Z. All parts are unanchored, massless,
--     non-colliding and welded to Root (Weld with explicit C0).
--   * Attributes: Kind (string), Ground (bool: sits on the ground instead
--     of in the hand), Engine (bool: plays the engine loop), RideLift
--     (studs the player is raised to stand on it).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tools = require(script.Parent.Config.Tools)
local ToolArt = require(script.Parent.Config.ToolArt)

local ToolModels = {}

export type KindInfo = { Ground: boolean, Engine: boolean, RideLift: number }

local KINDS: { [string]: KindInfo } = {
	clipper = { Ground = false, Engine = false, RideLift = 0 },
	scissors = { Ground = false, Engine = false, RideLift = 0 },
	sickle = { Ground = false, Engine = false, RideLift = 0 },
	trimmer = { Ground = false, Engine = true, RideLift = 0 },
	reel = { Ground = true, Engine = false, RideLift = 0 },
	push = { Ground = true, Engine = true, RideLift = 0 },
	rider = { Ground = true, Engine = true, RideLift = 1.4 },
	tractor = { Ground = true, Engine = true, RideLift = 2.2 },
}
ToolModels.Kinds = KINDS

local KIND_BY_TOOL: { [string]: string } = {
	nail_clipper = "clipper",
	safety_scissors = "scissors",
	kitchen_scissors = "scissors",
	garden_shears = "scissors",
	hand_sickle = "sickle",
	grass_whip = "sickle",
	reel_mower = "reel",
	turbo_reel = "reel",
	electric_reel = "reel",
	tractor_jr = "tractor",
	longhorn = "tractor",
	tractor_mower = "tractor",
	royal_tractor = "tractor",
}

local PALETTE = {
	Color3.fromRGB(214, 58, 48), -- red
	Color3.fromRGB(54, 150, 72), -- farm green
	Color3.fromRGB(240, 140, 30), -- orange
	Color3.fromRGB(246, 200, 40), -- yellow
	Color3.fromRGB(46, 112, 210), -- blue
	Color3.fromRGB(150, 70, 200), -- purple
}

local DARK = Color3.fromRGB(38, 38, 42)
local METAL = Color3.fromRGB(176, 182, 190)
local BLACK = Color3.fromRGB(24, 24, 26)

function ToolModels.KindOf(toolId: string): string
	local explicit = KIND_BY_TOOL[toolId]
	if explicit then
		return explicit
	end
	local def = Tools.ById[toolId]
	if not def then
		return "clipper"
	end
	if def.RequiredZone <= 1 then
		return "scissors"
	elseif def.RequiredZone == 2 then
		return "trimmer"
	elseif def.RequiredZone == 3 then
		return "push"
	elseif def.RequiredZone >= 6 then
		return "tractor"
	end
	return "rider"
end

local function colorOf(toolId: string): Color3
	local index = 0
	for i, def in Tools.List do
		if def.Id == toolId then
			index = i
			break
		end
	end
	return PALETTE[(index % #PALETTE) + 1]
end

-- Tools later in the ladder get physically bigger (up to +60%).
local function scaleOf(toolId: string): number
	local def = Tools.ById[toolId]
	if not def then
		return 1
	end
	local index = 0
	for i, other in Tools.List do
		if other == def then
			index = i
			break
		end
	end
	return 1 + 0.6 * (index - 1) / math.max(1, #Tools.List - 1)
end

-- Where the push handle's grip should be for the player who holds it, in
-- studs from the model origin (the ground under the player): Y up, Z
-- forward (negative). ToolVisualService measures the avatar's arms, so
-- small and tall avatars both push with straight-ish arms.
export type Fit = { GripY: number, GripZ: number }

type Builder = {
	Model: Model,
	Root: BasePart,
	Scale: number,
	Fit: Fit?,
}

local function part(b: Builder, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size * b.Scale
	p.CFrame = CFrame.new(cf.Position * b.Scale) * cf.Rotation
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = b.Model
	return p
end

-- Cylinder whose axis is X (Roblox cylinders are along X).
local function wheel(b: Builder, name: string, diameter: number, width: number, x: number, y: number, z: number)
	local w = part(b, name, Vector3.new(width, diameter, diameter), CFrame.new(x, y, z), BLACK, Enum.Material.Rubber, Enum.PartType.Cylinder)
	part(b, name .. "Hub", Vector3.new(width + 0.05, diameter * 0.45, diameter * 0.45), CFrame.new(x, y, z), METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	return w
end

-- A thin rod from a to b (model space, before scaling).
local function rod(b: Builder, name: string, a: Vector3, c: Vector3, thickness: number, color: Color3)
	local length = (c - a).Magnitude
	return part(b, name, Vector3.new(thickness, thickness, length), CFrame.lookAt((a + c) / 2, c), color, Enum.Material.Metal)
end

local function handle(b: Builder, deckBackZ: number, deckTopY: number, color: Color3, halfWidth: number?)
	-- part() multiplies positions by Scale, so undo it for the fitted grip.
	local gripY = if b.Fit then b.Fit.GripY / b.Scale else 2.2
	local gripZ = if b.Fit then b.Fit.GripZ / b.Scale else -1.7
	local w = halfWidth or 0.8
	for _, x in { -w, w } do
		rod(b, "HandleBar", Vector3.new(x, deckTopY, deckBackZ), Vector3.new(x * 0.8, gripY, gripZ), 0.18, color)
	end
	rod(b, "HandleGrip", Vector3.new(-0.75, gripY, gripZ), Vector3.new(0.75, gripY, gripZ), 0.26, DARK)
end

local BUILDERS: { [string]: (Builder, Color3) -> () } = {}

-- Hand kinds: grip at origin, item pointing down -Z.
BUILDERS.clipper = function(b, color)
	-- Lever-type nail clipper: two jaws joined at the back, a pin near the
	-- front, a lever on top with a colored thumb pad, and a key ring.
	-- Cartoon-sized (~2 studs) so it reads in the hand.
	local SILVER = Color3.fromRGB(205, 210, 218)
	part(b, "LowerJaw", Vector3.new(0.55, 0.1, 2.0), CFrame.new(0, -0.16, -0.95), SILVER, Enum.Material.Metal)
	part(b, "UpperJaw", Vector3.new(0.55, 0.1, 2.0), CFrame.new(0, -0.02, -0.95) * CFrame.Angles(math.rad(-4), 0, 0), SILVER, Enum.Material.Metal)
	part(b, "Hinge", Vector3.new(0.55, 0.24, 0.18), CFrame.new(0, -0.09, 0.0), SILVER, Enum.Material.Metal)
	-- Rounded cutting tips.
	part(b, "Tip", Vector3.new(0.24, 0.55, 0.55), CFrame.new(0, -0.09, -1.92) * CFrame.Angles(0, 0, math.rad(90)), METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	-- Pin through the jaws, under the lever.
	part(b, "Pin", Vector3.new(0.5, 0.14, 0.14), CFrame.new(0, 0.15, -1.45) * CFrame.Angles(0, 0, math.rad(90)), DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
	-- Lever: rises from the pin to above the grip.
	local from, to = Vector3.new(0, 0.38, -1.5), Vector3.new(0, 0.62, 0.15)
	part(b, "Lever", Vector3.new(0.5, 0.07, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), SILVER, Enum.Material.Metal)
	part(b, "LeverEnd", Vector3.new(0.07, 0.5, 0.5), CFrame.new(to) * CFrame.Angles(0, 0, math.rad(90)), SILVER, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(b, "ThumbPad", Vector3.new(0.36, 0.04, 0.5), CFrame.lookAt((from + to) / 2, to) * CFrame.new(0, 0.05, 0.45), color, Enum.Material.SmoothPlastic)
	-- Key ring at the back.
	part(b, "Ring", Vector3.new(0.06, 0.42, 0.42), CFrame.new(0, -0.16, 0.3) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(b, "RingHole", Vector3.new(0.08, 0.22, 0.22), CFrame.new(0, -0.16, 0.3) * CFrame.Angles(0, 0, math.rad(90)), DARK, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
end

BUILDERS.scissors = function(b, color)
	for _, side in { -1, 1 } do
		part(b, "Loop", Vector3.new(0.12, 0.5, 0.5), CFrame.new(side * 0.22, 0, 0), color, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		part(b, "Blade", Vector3.new(0.12, 0.08, 1.6), CFrame.new(side * 0.06, 0, -1.0) * CFrame.Angles(0, side * math.rad(6), 0), METAL, Enum.Material.Metal)
	end
end

BUILDERS.sickle = function(b, color)
	-- Wooden grip along -Z, then a crescent blade: a chain of short metal
	-- segments on a circle that starts at the grip's tip and curls forward
	-- and up (no gaps: each segment runs exactly from one point to the next).
	part(b, "Grip", Vector3.new(0.28, 0.28, 1.3), CFrame.new(0, 0, -0.45), color, Enum.Material.Wood)
	part(b, "Ferrule", Vector3.new(0.34, 0.34, 0.18), CFrame.new(0, 0, -1.1), METAL, Enum.Material.Metal)
	local radius = 0.85
	local center = Vector3.new(0, radius, -1.15)
	local function point(angle: number): Vector3
		-- angle 0 = bottom of the circle (the grip's tip), turning forward.
		return center + Vector3.new(0, -radius * math.cos(angle), -radius * math.sin(angle))
	end
	local steps = 8
	for i = 0, steps - 1 do
		local a1 = math.rad(i * 200 / steps)
		local a2 = math.rad((i + 1) * 200 / steps)
		local p1, p2 = point(a1), point(a2)
		local width = 0.26 * (1 - i / steps) + 0.06 -- tapers to a point
		part(b, "Blade", Vector3.new(0.06, width, (p2 - p1).Magnitude + 0.04), CFrame.lookAt((p1 + p2) / 2, p2), METAL, Enum.Material.Metal)
	end
end

BUILDERS.trimmer = function(b, color)
	part(b, "Shaft", Vector3.new(0.18, 0.18, 4.2), CFrame.new(0, 0, -1.6), METAL, Enum.Material.Metal)
	part(b, "Motor", Vector3.new(0.6, 0.6, 0.9), CFrame.new(0, 0, 0.4), color).Name = "Engine"
	part(b, "Guard", Vector3.new(0.12, 1.1, 1.1), CFrame.new(0, 0, -3.8) * CFrame.Angles(math.rad(90), 0, math.rad(90)), color, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(b, "Head", Vector3.new(0.35, 0.5, 0.5), CFrame.new(0, 0, -3.8) * CFrame.Angles(math.rad(90), 0, math.rad(90)), DARK, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
end

-- Ground kinds: origin on the ground under the player, model in front (-Z).
BUILDERS.reel = function(b, color)
	local z = -3
	wheel(b, "WheelL", 1.6, 0.3, -1.3, 0.8, z)
	wheel(b, "WheelR", 1.6, 0.3, 1.3, 0.8, z)
	part(b, "Reel", Vector3.new(2.3, 0.9, 0.9), CFrame.new(0, 0.6, z), METAL, Enum.Material.DiamondPlate, Enum.PartType.Cylinder)
	for i = 0, 3 do
		part(b, "ReelBlade", Vector3.new(2.3, 0.08, 0.5), CFrame.new(0, 0.6, z) * CFrame.Angles(math.rad(i * 45), 0, 0), color, Enum.Material.Metal)
	end
	part(b, "Roller", Vector3.new(2.2, 0.35, 0.35), CFrame.new(0, 0.18, z + 0.9), DARK, Enum.Material.Rubber, Enum.PartType.Cylinder)
	handle(b, z + 0.5, 0.9, color)
end

BUILDERS.push = function(b, color)
	local z = -3.2
	part(b, "Deck", Vector3.new(3, 0.7, 3.2), CFrame.new(0, 0.85, z), color)
	part(b, "Skirt", Vector3.new(3.1, 0.3, 3.3), CFrame.new(0, 0.45, z), DARK)
	for _, x in { -1.45, 1.45 } do
		for _, dz in { -1.2, 1.2 } do
			wheel(b, "Wheel", 0.9, 0.35, x, 0.45, z + dz)
		end
	end
	part(b, "Engine", Vector3.new(1.3, 0.9, 1.3), CFrame.new(0, 1.65, z - 0.2), DARK, Enum.Material.Metal)
	part(b, "Cap", Vector3.new(0.5, 0.25, 0.5), CFrame.new(0.35, 2.2, z - 0.2), color)
	part(b, "Bag", Vector3.new(1.8, 1.2, 1.2), CFrame.new(0, 1.0, z + 2.0), Color3.fromRGB(70, 74, 60), Enum.Material.Fabric)
	handle(b, z + 1.5, 1.2, color)
end

BUILDERS.rider = function(b, color)
	-- The player stands on the deck (RideLift); the seat is behind them.
	part(b, "Chassis", Vector3.new(3.4, 0.8, 5.6), CFrame.new(0, 0.95, -0.7), color)
	part(b, "Hood", Vector3.new(3, 1.0, 2.0), CFrame.new(0, 1.8, -2.4), color).Name = "Engine"
	part(b, "Grille", Vector3.new(2.4, 0.7, 0.1), CFrame.new(0, 1.8, -3.45), DARK, Enum.Material.DiamondPlate)
	part(b, "Seat", Vector3.new(2, 1.6, 0.5), CFrame.new(0, 2.2, 1.6), DARK, Enum.Material.Fabric)
	rod(b, "Column", Vector3.new(0, 1.6, -1.4), Vector3.new(0, 3.2, -1.0), 0.2, DARK)
	part(b, "SteeringWheel", Vector3.new(0.15, 1.2, 1.2), CFrame.new(0, 3.2, -1.0) * CFrame.Angles(math.rad(90), math.rad(20), math.rad(90)), BLACK, Enum.Material.Rubber, Enum.PartType.Cylinder)
	part(b, "MowDeck", Vector3.new(4.4, 0.4, 2.4), CFrame.new(0, 0.35, -0.6), DARK, Enum.Material.Metal)
	wheel(b, "FrontWheel", 1.0, 0.5, -1.6, 0.5, -2.6)
	wheel(b, "FrontWheel", 1.0, 0.5, 1.6, 0.5, -2.6)
	wheel(b, "RearWheel", 1.6, 0.7, -1.9, 0.8, 1.4)
	wheel(b, "RearWheel", 1.6, 0.7, 1.9, 0.8, 1.4)
end

BUILDERS.tractor = function(b, color)
	part(b, "Chassis", Vector3.new(3.2, 1.0, 6.4), CFrame.new(0, 1.6, -1.2), color)
	part(b, "Hood", Vector3.new(2.6, 1.4, 3.4), CFrame.new(0, 2.6, -2.8), color).Name = "Engine"
	part(b, "Exhaust", Vector3.new(0.3, 1.8, 0.3), CFrame.new(0.9, 4.1, -2.0), DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(b, "Seat", Vector3.new(1.8, 1.8, 0.5), CFrame.new(0, 3.0, 1.4), DARK, Enum.Material.Fabric)
	for _, x in { -1.5, 1.5 } do
		rod(b, "RollBar", Vector3.new(x, 2.1, 1.9), Vector3.new(x, 6.2, 1.9), 0.25, DARK)
	end
	rod(b, "RollBarTop", Vector3.new(-1.5, 6.2, 1.9), Vector3.new(1.5, 6.2, 1.9), 0.25, DARK)
	rod(b, "Column", Vector3.new(0, 2.6, -1.2), Vector3.new(0, 4.0, -0.9), 0.22, DARK)
	part(b, "SteeringWheel", Vector3.new(0.15, 1.3, 1.3), CFrame.new(0, 4.0, -0.9) * CFrame.Angles(math.rad(90), math.rad(25), math.rad(90)), BLACK, Enum.Material.Rubber, Enum.PartType.Cylinder)
	wheel(b, "FrontWheel", 1.6, 0.6, -1.7, 0.8, -3.6)
	wheel(b, "FrontWheel", 1.6, 0.6, 1.7, 0.8, -3.6)
	wheel(b, "RearWheel", 3.0, 0.9, -2.0, 1.5, 1.0)
	wheel(b, "RearWheel", 3.0, 0.9, 2.0, 1.5, 1.0)
	part(b, "MowDeck", Vector3.new(6, 0.5, 2.0), CFrame.new(0, 0.4, -5.6), DARK, Enum.Material.Metal)
	part(b, "DeckTrim", Vector3.new(6.1, 0.2, 2.1), CFrame.new(0, 0.75, -5.6), color)
end

-- Where the hands go (ToolPoses.client.luau): Attachments "GripL"/"GripR"
-- on the push handle or the steering wheel. Override models can carry
-- their own GripL/GripR attachments.
local function addGrips(model: Model)
	if model:FindFirstChild("GripL", true) then
		return
	end
	local handle = model:FindFirstChild("HandleGrip") :: BasePart?
	local wheel = model:FindFirstChild("SteeringWheel") :: BasePart?
	local host = handle or wheel
	if not host then
		return
	end
	-- The model is still at the origin facing -Z, so its left is world -X.
	-- Spread the hands over the bar/wheel's width along X.
	local r = host.CFrame.RightVector
	local u = host.CFrame.UpVector
	local l = host.CFrame.LookVector
	local width = math.abs(r.X) * host.Size.X + math.abs(u.X) * host.Size.Y + math.abs(l.X) * host.Size.Z
	local spread = width * (if handle then 0.32 else 0.4)
	for name, side in { GripL = -1, GripR = 1 } do
		local a = Instance.new("Attachment")
		a.Name = name
		a.Parent = host
		-- Orientation the hand should take (ToolPoses uses IK Transform):
		-- fingers forward (-Z) and palm down over the bar. R15 hands hang
		-- with fingers -Y and palms facing the body (right palm -X, left
		-- +X); pitch 90 deg forward, then roll the palm down.
		local roll = if side > 0 then math.rad(90) else -math.rad(90)
		a.WorldCFrame = CFrame.new(host.Position + Vector3.new(side * spread, 0, 0)) * CFrame.Angles(0, 0, roll) * CFrame.Angles(math.rad(90), 0, 0)
	end
end

local function finish(model: Model, root: BasePart, kind: string)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			descendant.CastShadow = descendant.Size.Magnitude > 2
			if descendant ~= root then
				-- A Weld with an explicit offset, not a WeldConstraint: a
				-- WeldConstraint records the offset when it activates, which
				-- can be after the root was already moved onto the player,
				-- leaving the parts stranded far away.
				local weld = Instance.new("Weld")
				weld.Part0 = root
				weld.Part1 = descendant
				weld.C0 = root.CFrame:ToObjectSpace(descendant.CFrame)
				weld.Parent = descendant
			end
		end
	end
	local info = KINDS[kind]
	model:SetAttribute("Kind", kind)
	model:SetAttribute("Ground", info.Ground)
	model:SetAttribute("Engine", info.Engine)
	model:SetAttribute("RideLift", info.RideLift)
end

local function newRoot(model: Model): BasePart
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root
	return root
end

-- A model from ReplicatedStorage/Assets/Tools, fitted to the kind's spot.
-- Longest side, in studs, of hand tools (override models and built ones).
local HOLD_LENGTH: { [string]: number } = {
	clipper = 1.0,
	scissors = 1.8,
	sickle = 2.2,
	trimmer = 4.6,
}

local function fromOverride(template: Model, kind: string): (Model, BasePart)
	local model = Instance.new("Model")
	local root = newRoot(model)
	local copy = template:Clone()
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy() -- audit rule: assets never bring code
		end
	end
	local info = KINDS[kind]
	-- Hand tools are resized to a believable length in the hand, whatever
	-- size the asset was published at.
	local holdLength = HOLD_LENGTH[kind]
	if holdLength then
		local _, size = copy:GetBoundingBox()
		copy:ScaleTo(copy:GetScale() * holdLength / math.max(size.X, size.Y, size.Z))
	end
	local boxCFrame, boxSize = copy:GetBoundingBox()
	local target: CFrame
	if info.Ground then
		-- Bottom on the ground, front half of it ahead of the player.
		target = CFrame.new(0, boxSize.Y / 2, if info.RideLift > 0 then -0.8 else -(boxSize.Z / 2 + 1.2))
	else
		target = CFrame.new(0, 0, -boxSize.Z / 2 + 0.3)
	end
	copy:PivotTo(target * boxCFrame:ToObjectSpace(copy:GetPivot()))
	for _, child in copy:GetChildren() do
		child.Parent = model
	end
	copy:Destroy()
	return model, root
end

-- The Blender art: a loaded base mesh (ReplicatedStorage/ToolArt/<Model>),
-- painted, trimmed to the tool's extras and put back where it was
-- authored (grip / player at the origin), then sized for this tool.
local function largest(v: Vector3): number
	return math.max(v.X, v.Y, v.Z)
end

local function artTemplate(toolId: string): (Model?, ToolArt.ToolLook?, ToolArt.ModelDef?)
	local look = ToolArt.Tools[toolId]
	local def = look and ToolArt.Models[look.Model]
	local folder = ReplicatedStorage:FindFirstChild("ToolArt")
	local template = folder and look and folder:FindFirstChild(look.Model)
	if template and template:IsA("Model") then
		return template, look, def
	end
	return nil, nil, nil
end

-- Paint one mesh piece by its group name (extra and rig already split off).
local function paint(piece: BasePart, look: ToolArt.ToolLook)
	if piece.Name == "Accent" then
		piece.Color = look.Color
		piece.Material = Enum.Material.SmoothPlastic
	elseif piece.Name == "Accent2" then
		piece.Color = look.Color2
		piece.Material = Enum.Material.SmoothPlastic
	elseif piece.Name == "Glow" then
		piece.Color = look.Color2
		piece.Material = Enum.Material.Neon
	elseif piece.Name == "Crystal" then
		piece.Color = look.Color2
		piece.Material = Enum.Material.Glass
		piece.Transparency = 0.25
	else
		local spec = ToolArt.Pieces[piece.Name]
		if spec then
			piece.Color = spec.Color
			piece.Material = spec.Material
			piece.Transparency = spec.Transparency or 0
		end
	end
	if piece:IsA("MeshPart") then
		piece.TextureID = ""
	end
	local appearance = piece:FindFirstChildOfClass("SurfaceAppearance")
	if appearance then
		appearance:Destroy() -- the importer's material would hide the paint
	end
end

-- Golden / Rainbow / Void: special paint, a glow and particles on the
-- biggest Accent piece. Rainbow pieces are tagged "RainbowPiece" and
-- recoloured every frame by ToolAnimations.client.
local function applyFinish(model: Model, look: ToolArt.ToolLook)
	local finish = look.Finish and ToolArt.Finishes[look.Finish]
	if not finish then
		return
	end
	local host: BasePart? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "Accent" then
				d.Color = finish.Color
				d.Material = finish.Material
				if finish.Rainbow then
					CollectionService:AddTag(d, "RainbowPiece")
				end
				if not host or d.Size.Magnitude > host.Size.Magnitude then
					host = d
				end
			elseif d.Name == "Accent2" or d.Name == "Glow" then
				d.Color = finish.Color2
				d.Material = Enum.Material.Neon
			end
		end
	end
	if not host then
		return
	end
	local p = finish.Particle
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "FinishParticles"
	emitter.Texture = p.Texture
	emitter.Color = p.Color
	emitter.Rate = p.Rate
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, p.Size), NumberSequenceKeypoint.new(1, 0) })
	emitter.LightEmission = p.LightEmission
	emitter.Lifetime = NumberRange.new(0.8, 1.6)
	emitter.Speed = NumberRange.new(0.5, 2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Acceleration = Vector3.new(0, 1.5, 0)
	emitter.Parent = host
	local light = Instance.new("PointLight")
	light.Name = "FinishLight"
	light.Color = finish.Light
	light.Range = 10
	light.Brightness = 1.2
	light.Parent = host
end

local function fromArt(template: Model, look: ToolArt.ToolLook, def: ToolArt.ModelDef, toolId: string, kind: string, fit: Fit?): (Model, BasePart, number)
	local model = Instance.new("Model")
	local root = newRoot(model)
	local copy = template:Clone()
	-- 1. Back to the authored size and place (the bounding box covers every
	--    piece, extras included, exactly like art/tools/out/meta.json).
	local box, size = copy:GetBoundingBox()
	copy:ScaleTo(copy:GetScale() * largest(def.Size) / largest(size))
	box = copy:GetBoundingBox()
	copy:PivotTo(CFrame.new(def.Center) * box:ToObjectSpace(copy:GetPivot()))
	-- 2. Keep the extras this tool lists, paint everything.
	local keep: { [string]: boolean } = {}
	for _, extra in look.Extras or {} do
		keep[extra] = true
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			-- "Group.Extra#Rig": the rig is what ToolAnimations moves.
			local name, rigName = string.match(d.Name, "^([^#]+)#(.+)$")
			if name and rigName then
				d.Name = name
				d:SetAttribute("Rig", rigName)
			end
			local group, extra = string.match(d.Name, "^([^%.]+)%.(.+)$")
			if group and extra then
				if keep[extra] then
					d.Name = group
				else
					d:Destroy()
					continue
				end
			end
			paint(d, look)
		end
	end
	-- Seated ride-ons: slide the machine so its seat is under the player.
	if def.Seat then
		copy:PivotTo(copy:GetPivot() - Vector3.new(0, 0, def.Seat.Z))
	end
	for _, child in copy:GetChildren() do
		child.Parent = model
	end
	copy:Destroy()
	-- 3. Size for this tool, around the grip / the player (the origin).
	local info = KINDS[kind]
	local scale = if info.Ground then (look.Scale or 1) else (def.HoldLength or largest(def.Size)) / largest(def.Size)
	model.WorldPivot = CFrame.identity
	if math.abs(scale - 1) > 1e-3 then
		model:ScaleTo(scale)
	end
	applyFinish(model, look)
	if def.Seat then
		model:SetAttribute("SeatHeight", def.Seat.Y * scale) -- ToolVisualService sits the player here
	end
	-- Hinge of the blades / lever, for the open-close animation.
	if def.Snip then
		model:SetAttribute("SnipPivot", def.Snip.Pivot * scale)
		model:SetAttribute("SnipAxis", def.Snip.Axis)
		model:SetAttribute("SnipAngle", def.Snip.Angle)
	end
	-- 4. Push mowers: the handle is built to fit the player's arms.
	if def.Handle then
		local builder: Builder = { Model = model, Root = root, Scale = scale, Fit = fit }
		handle(builder, def.Handle.Z, def.Handle.Y, look.Color, def.Handle.X)
	end
	return model, root, scale
end

-- Builds the model for a tool at the origin (Root at CFrame.identity).
function ToolModels.Build(toolId: string, fit: Fit?): Model
	local kind = ToolModels.KindOf(toolId)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local overrides = assets and assets:FindFirstChild("Tools")
	local template = overrides and overrides:FindFirstChild(toolId)
	local art, look, def = artTemplate(toolId)
	if not template and art and look and def then
		local model, root, scale = fromArt(art, look, def, toolId, kind, fit)
		model.Name = "ToolModel"
		model:SetAttribute("ToolId", toolId)
		if KINDS[kind].Ground then
			addGrips(model) -- hand tools hold by the origin; GripL/R would turn on the two-hand pose
		end
		finish(model, root, kind)
		if KINDS[kind].RideLift > 0 and def.RideLift then
			model:SetAttribute("RideLift", def.RideLift * scale)
		end
		return model
	end
	if not template and RunService:IsServer() then
		-- Models Rojo can't carry (Unions, MeshParts) live in the place file:
		-- ServerStorage/ToolOverrides/<ToolId> (see assets/README.md).
		local placeOverrides = game:GetService("ServerStorage"):FindFirstChild("ToolOverrides")
		template = placeOverrides and placeOverrides:FindFirstChild(toolId)
	end

	local model: Model, root: BasePart
	if template and template:IsA("Model") then
		model, root = fromOverride(template, kind)
	else
		model = Instance.new("Model")
		root = newRoot(model)
		local handScale = if kind == "clipper" then 0.42 else 1 -- built clipper is ~2.4 studs long
		local builder: Builder = { Model = model, Root = root, Scale = if KINDS[kind].Ground then scaleOf(toolId) else handScale, Fit = fit }
		BUILDERS[kind](builder, colorOf(toolId))
	end
	model.Name = "ToolModel"
	model:SetAttribute("ToolId", toolId)
	addGrips(model)
	finish(model, root, kind)
	return model
end

return ToolModels
