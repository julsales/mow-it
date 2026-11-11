--!strict
-- Placeholder 3D models for the tool ladder, built from Parts (the Asset
-- Picker's pick for tools: no free mower with a clear license exists, so
-- simulator tools are built in Studio from Parts). A few shapes ("kinds")
-- cover all 48 tools; color and scale change per tool, so every upgrade
-- looks different.
--
-- Override any tool with a real model: put a Model named after the tool id
-- in ReplicatedStorage/Assets/Tools (repo: assets/Tools/<ToolId>.rbxm,
-- see assets/README.md). It replaces the built one, no code change.
--
-- Model contract (what ToolVisualService and the client rely on):
--   * PrimaryPart "Root": for hand kinds = the grip; for ground kinds = a
--     point on the ground right under the player's HumanoidRootPart.
--   * Front of the model is -Z. All parts are unanchored, massless,
--     non-colliding and welded to Root (Weld with explicit C0).
--   * Attributes: Kind (string), Ground (bool: sits on the ground instead
--     of in the hand), Engine (bool: plays the engine loop), RideLift
--     (studs the player is raised to stand on it).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tools = require(script.Parent.Config.Tools)

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

type Builder = {
	Model: Model,
	Root: BasePart,
	Scale: number,
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

local function handle(b: Builder, deckBackZ: number, deckTopY: number, color: Color3)
	for _, x in { -0.8, 0.8 } do
		rod(b, "HandleBar", Vector3.new(x, deckTopY, deckBackZ), Vector3.new(x * 0.8, 2.9, -1.4), 0.18, color)
	end
	rod(b, "HandleGrip", Vector3.new(-0.75, 2.9, -1.4), Vector3.new(0.75, 2.9, -1.4), 0.26, DARK)
end

local BUILDERS: { [string]: (Builder, Color3) -> () } = {}

-- Hand kinds: grip at origin, item pointing down -Z.
BUILDERS.clipper = function(b, color)
	part(b, "Body", Vector3.new(0.35, 0.12, 1.1), CFrame.new(0, 0, -0.55), METAL, Enum.Material.Metal)
	part(b, "Lever", Vector3.new(0.3, 0.08, 0.9), CFrame.new(0, 0.14, -0.5) * CFrame.Angles(math.rad(8), 0, 0), color)
end

BUILDERS.scissors = function(b, color)
	for _, side in { -1, 1 } do
		part(b, "Loop", Vector3.new(0.12, 0.5, 0.5), CFrame.new(side * 0.22, 0, 0), color, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		part(b, "Blade", Vector3.new(0.12, 0.08, 1.6), CFrame.new(side * 0.06, 0, -1.0) * CFrame.Angles(0, side * math.rad(6), 0), METAL, Enum.Material.Metal)
	end
end

BUILDERS.sickle = function(b, color)
	part(b, "Grip", Vector3.new(0.25, 0.25, 1.1), CFrame.new(0, 0, -0.3), color, Enum.Material.Wood)
	for i = 0, 4 do
		local angle = math.rad(-20 + i * 32)
		local center = Vector3.new(0, math.sin(angle) * 0.9, -0.9 - math.cos(angle) * 0.9 + 0.9)
		part(b, "Blade", Vector3.new(0.06, 0.18, 0.6), CFrame.new(center + Vector3.new(0, 0.6, -0.9)) * CFrame.Angles(angle, 0, 0), METAL, Enum.Material.Metal)
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
	local spread = if handle then handle.Size.Z * 0.32 else host.Size.Y * 0.4
	for name, side in { GripL = -1, GripR = 1 } do
		local a = Instance.new("Attachment")
		a.Name = name
		a.Parent = host
		a.WorldPosition = host.Position + Vector3.new(side * spread, 0, 0)
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

-- Builds the model for a tool at the origin (Root at CFrame.identity).
function ToolModels.Build(toolId: string): Model
	local kind = ToolModels.KindOf(toolId)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local overrides = assets and assets:FindFirstChild("Tools")
	local template = overrides and overrides:FindFirstChild(toolId)

	local model: Model, root: BasePart
	if template and template:IsA("Model") then
		model, root = fromOverride(template, kind)
	else
		model = Instance.new("Model")
		root = newRoot(model)
		local builder: Builder = { Model = model, Root = root, Scale = if KINDS[kind].Ground then scaleOf(toolId) else 1 }
		BUILDERS[kind](builder, colorOf(toolId))
	end
	model.Name = "ToolModel"
	model:SetAttribute("ToolId", toolId)
	addGrips(model)
	finish(model, root, kind)
	return model
end

return ToolModels
