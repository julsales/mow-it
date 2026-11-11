--!strict
-- The LOOK of the grass. The server (GrassService) only keeps the state of
-- each cell in attributes (Health, MaxHealth, Cut) on Parts tagged
-- "GrassCell"; this script turns that into visuals, locally:
--   * height follows Health (tough grass gets shorter with each hit),
--   * Cut = true -> shrink to stubble, lighter "mowed" color in stripes,
--     burst of clippings,
--   * Cut = false -> grows back with a tween,
--   * blades on top of every cell: ReplicatedStorage/Assets/Grass/GrassTuft
--     if it exists (assets/README.md), otherwise two green wedges.
--
-- Thousands of cells are alive at once, so everything here is cheap:
-- anchored, no collision/query/touch, no shadows, no per-frame loops.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.GameConfig)

local TALL = GameConfig.GrassTallHeight
local STUBBLE = GameConfig.GrassStubbleHeight
local CELL = GameConfig.GrassCellSize
local MOWED_TINT = Color3.fromRGB(214, 222, 140)
local STRIPE_WIDTH = CELL * 2 -- lawn stripes alternate every 2 cells along X

local CUT_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HIT_TWEEN = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local GROW_TWEEN = TweenInfo.new(1.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local decorFolder = Instance.new("Folder")
decorFolder.Name = "GrassDecor (local)"
decorFolder.Parent = Workspace

-- Blade prototype -------------------------------------------------------------

local function makeLocal(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

-- Returns a Model whose WorldPivot is the center of its base, sized to sit
-- on one cell. Built once and cloned per cell.
local function buildPrototype(): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local grassFolder = assets and assets:FindFirstChild("Grass")
	local tuft = grassFolder and grassFolder:FindFirstChild("GrassTuft")

	if tuft and (tuft:IsA("Model") or tuft:IsA("BasePart")) then
		local model: Model
		if tuft:IsA("Model") then
			model = tuft:Clone()
		else
			model = Instance.new("Model")
			tuft:Clone().Parent = model
		end
		for _, d in model:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				d:Destroy() -- assets never bring code
			elseif d:IsA("BasePart") then
				makeLocal(d)
			end
		end
		local boxCFrame, boxSize = model:GetBoundingBox()
		local fit = math.min(CELL * 0.95 / math.max(boxSize.X, boxSize.Z, 0.01), TALL * 0.9 / math.max(boxSize.Y, 0.01))
		model.WorldPivot = boxCFrame * CFrame.new(0, -boxSize.Y / 2, 0)
		model:ScaleTo(model:GetScale() * fit)
		model.Name = "Blades"
		return model
	end

	-- Fallback: two crossed thin wedges, a little brighter than the turf.
	local model = Instance.new("Model")
	model.Name = "Blades"
	for i, spec in { { x = -0.55, z = -0.35, yaw = 15, h = 1.0 }, { x = 0.5, z = 0.45, yaw = 105, h = 0.8 } } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Blade" .. i
		wedge.Size = Vector3.new(0.15, spec.h, 0.9)
		wedge.CFrame = CFrame.new(spec.x, spec.h / 2, spec.z) * CFrame.Angles(0, math.rad(spec.yaw), 0)
		wedge.Material = Enum.Material.SmoothPlastic
		wedge.Color = Color3.fromRGB(110, 196, 78)
		wedge.TopSurface = Enum.SurfaceType.Smooth
		wedge.BottomSurface = Enum.SurfaceType.Smooth
		makeLocal(wedge)
		wedge.Parent = model
	end
	model.WorldPivot = CFrame.identity
	return model
end

local prototype = buildPrototype()
local usesTuftAsset = prototype:FindFirstChild("Blade1") == nil

-- Clippings ---------------------------------------------------------------------
-- A small pool of tiny parts thrown up and dropped with tweens. Capped per
-- burst so mowing a huge radius never spawns hundreds of parts.

local CLIP_POOL_SIZE = 80
local clipPool: { BasePart } = {}
local clipNext = 1
for i = 1, CLIP_POOL_SIZE do
	local bit = Instance.new("Part")
	bit.Name = "Clipping"
	bit.Size = Vector3.new(0.12, 0.12, 0.45)
	bit.Material = Enum.Material.SmoothPlastic
	bit.Transparency = 1
	makeLocal(bit)
	bit.Parent = decorFolder
	clipPool[i] = bit
end

local clipsThisFrame = 0
local MAX_CLIPS_PER_FRAME = 30

local function burst(position: Vector3, color: Color3)
	for _ = 1, 3 do
		if clipsThisFrame >= MAX_CLIPS_PER_FRAME then
			return
		end
		if clipsThisFrame == 0 then
			task.defer(function()
				clipsThisFrame = 0
			end)
		end
		clipsThisFrame += 1
		local bit = clipPool[clipNext]
		clipNext = clipNext % CLIP_POOL_SIZE + 1

		local spin = CFrame.Angles(math.random() * 6.28, math.random() * 6.28, 0)
		local offset = Vector3.new((math.random() - 0.5) * 2.4, 0, (math.random() - 0.5) * 2.4)
		bit.Color = color
		bit.Transparency = 0
		bit.CFrame = CFrame.new(position) * spin
		local peak = position + offset * 0.6 + Vector3.new(0, 1.2 + math.random(), 0)
		local landing = position + offset + Vector3.new(0, -0.1, 0)
		local up = TweenService:Create(bit, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(peak) * spin * CFrame.Angles(1.5, 0, 0),
		})
		up.Completed:Once(function()
			TweenService:Create(bit, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = CFrame.new(landing) * spin * CFrame.Angles(3, 0, 1),
				Transparency = 1,
			}):Play()
		end)
		up:Play()
	end
end

-- Cells -------------------------------------------------------------------------

type CellState = {
	BaseY: number,
	FullHeight: number,
	Color: Color3,
	MowedColor: Color3,
	Blades: Model,
	BladesShown: boolean,
	Cut: boolean,
	Connections: { RBXScriptConnection },
}

local cells: { [BasePart]: CellState } = {}

local function topCFrame(part: BasePart, state: CellState, height: number): CFrame
	local p = part.Position
	return CFrame.new(p.X, state.BaseY + height, p.Z)
end

local function heightFor(part: BasePart, state: CellState): number
	if part:GetAttribute("Cut") then
		return STUBBLE
	end
	local health = (part:GetAttribute("Health") :: number?) or 1
	local maxHealth = math.max((part:GetAttribute("MaxHealth") :: number?) or 1, 1)
	local ratio = math.clamp(health / maxHealth, 0, 1)
	return STUBBLE + (state.FullHeight - STUBBLE) * ratio
end

local function setBlades(state: CellState, shown: boolean)
	if state.BladesShown ~= shown then
		state.BladesShown = shown
		state.Blades.Parent = if shown then decorFolder else nil
	end
end

local function apply(part: BasePart, state: CellState, tween: TweenInfo?)
	local height = heightFor(part, state)
	local p = part.Position
	local goal = {
		Size = Vector3.new(part.Size.X, height, part.Size.Z),
		CFrame = CFrame.new(p.X, state.BaseY + height / 2, p.Z),
		Color = if state.Cut then state.MowedColor else state.Color,
	}
	local yaw = state.Blades:GetAttribute("Yaw") :: number
	local bladesAt = topCFrame(part, state, height) * CFrame.Angles(0, yaw, 0)
	if tween then
		TweenService:Create(part, tween, goal):Play()
	else
		part.Size = goal.Size
		part.CFrame = goal.CFrame
		part.Color = goal.Color
	end
	state.Blades:PivotTo(bladesAt)
	setBlades(state, not state.Cut)
end

local function onCutChanged(part: BasePart, state: CellState)
	local cut = part:GetAttribute("Cut") == true
	if cut == state.Cut then
		return
	end
	state.Cut = cut
	if cut then
		burst(part.Position + Vector3.new(0, part.Size.Y / 2, 0), state.Color)
		apply(part, state, CUT_TWEEN)
	else
		-- Regrow: start from stubble, blades pop back in as it grows.
		apply(part, state, GROW_TWEEN)
	end
end

local function addCell(instance: Instance)
	if not instance:IsA("BasePart") or cells[instance] then
		return
	end
	local part = instance :: BasePart
	-- The server never resizes cells, so what arrives is the full height.
	local fullHeight = part.Size.Y
	local stripe = math.floor(part.Position.X / STRIPE_WIDTH) % 2 == 0
	local mowed = part.Color:Lerp(MOWED_TINT, if stripe then 0.35 else 0.5)

	local blades = prototype:Clone()
	blades:SetAttribute("Yaw", math.random() * math.pi * 2)
	if not usesTuftAsset then
		local shade = math.random() * 0.15
		for _, d in blades:GetChildren() do
			if d:IsA("BasePart") then
				d.Color = d.Color:Lerp(part.Color, 0.4 + shade)
			end
		end
	end

	local state: CellState = {
		BaseY = part.Position.Y - fullHeight / 2,
		FullHeight = fullHeight,
		Color = part.Color,
		MowedColor = mowed,
		Blades = blades,
		BladesShown = false,
		Cut = part:GetAttribute("Cut") == true,
		Connections = {},
	}
	cells[part] = state

	table.insert(state.Connections, part:GetAttributeChangedSignal("Cut"):Connect(function()
		onCutChanged(part, state)
	end))
	table.insert(state.Connections, part:GetAttributeChangedSignal("Health"):Connect(function()
		if not state.Cut and part:GetAttribute("Cut") ~= true then
			apply(part, state, HIT_TWEEN) -- tough grass got shorter
		end
	end))

	apply(part, state, nil)
end

local function removeCell(instance: Instance)
	local part = instance :: BasePart
	local state = cells[part]
	if not state then
		return
	end
	cells[part] = nil
	for _, connection in state.Connections do
		connection:Disconnect()
	end
	state.Blades:Destroy()
end

CollectionService:GetInstanceAddedSignal("GrassCell"):Connect(addCell)
CollectionService:GetInstanceRemovedSignal("GrassCell"):Connect(removeCell)

-- Cells already streamed in: spread over frames so joining doesn't hitch.
task.spawn(function()
	for i, instance in CollectionService:GetTagged("GrassCell") do
		addCell(instance)
		if i % 300 == 0 then
			task.wait()
		end
	end
end)
