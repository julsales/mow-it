--!strict
-- Grass on the lawns. MapService decides WHERE lawns are (cell centers per
-- zone, painted as Terrain Grass, whose 3D blades sway in the wind); this
-- service owns the STATE of every cell: health, grass type, cut/regrowth.
--
-- Mowing = changing the Terrain material of one 4x4 voxel column:
--   Grass (tall blades) -> Ground / Mud recolored as short lawn,
-- alternating every GrassStripeCells cells, so mowed lawns show light/dark
-- stripes. Regrowth swaps it back. Terrain edits replicate on their own.
--
-- Grass types (Shared/Config/GrassTypes.luau): most cells grow the area's
-- normal grass; by luck (chances per area in MapLayout.luau) a cell grows
-- a rarer type that yields more. Rare cells get a sparkle marker
-- (Workspace/RareGrass) so players can spot and chase them.
--
-- Cutting is grid math (a dictionary lookup per cell), never raycasts.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)
local GameConfig = require(Shared.Config.GameConfig)
local GrassTypes = require(Shared.Config.GrassTypes)
local MapLayout = require(Shared.Config.MapLayout)

local GrassService = {}

export type Cell = {
	ZoneId: string,
	MaxHealth: number,
	Health: number,
	Cut: boolean,
	Center: Vector3, -- top of the lawn at the cell's center
	Region: Region3,
	MowedMaterial: Enum.Material,
	TypeId: string,
	Yield: number, -- grass gained when this cell is cut
	Marker: BasePart?, -- sparkle for rare types
}

local CELL = 4 -- Terrain voxel size; GameConfig.GrassCellSize documents it
local STRIPE = GameConfig.GrassStripeCells or 2
local TALL = Enum.Material.Grass
local MOWED_LIGHT = Enum.Material.Ground
local MOWED_DARK = Enum.Material.Mud

local cells: { [string]: Cell } = {} -- "ix,iz" -> cell
local cellCount = 0
local terrain = Workspace.Terrain
local rng = Random.new()
local markers: Folder

local function paintColors()
	if not terrain.Decoration then
		-- Decoration can't be set from a script at runtime: it is on in the
		-- project file and must be saved in the place (Terrain > Decoration).
		warn("[MowIt][Grass] Workspace.Terrain.Decoration is off: lawns will look flat.")
	end
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(76, 124, 56)) -- wild ground
	terrain:SetMaterialColor(TALL, Color3.fromRGB(92, 168, 60)) -- uncut lawn
	terrain:SetMaterialColor(MOWED_LIGHT, Color3.fromRGB(150, 204, 92))
	terrain:SetMaterialColor(MOWED_DARK, Color3.fromRGB(116, 178, 70))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(206, 186, 140)) -- paths
end

-- Picks this cell's grass type (normal, or a lucky rare one).
local function rollType(zoneId: string): GrassTypes.GrassType
	local def = MapLayout.Areas[zoneId]
	local roll = rng:NextNumber()
	if def and roll < def.GoldenChance then
		return GrassTypes.ById.golden
	elseif def and roll < def.GoldenChance + def.LuckyChance then
		return GrassTypes.ById.lucky
	end
	return GrassTypes.ById.normal
end

local function setMarker(cell: Cell, grassType: GrassTypes.GrassType)
	if cell.Marker then
		cell.Marker:Destroy()
		cell.Marker = nil
	end
	if not grassType.Color then
		return
	end
	local marker = Instance.new("Part")
	marker.Name = grassType.Id
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.CastShadow = false
	marker.Transparency = 1
	marker.Size = Vector3.new(CELL, 0.2, CELL)
	marker.Position = cell.Center + Vector3.new(0, 0.6, 0)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(grassType.Color)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(0.5, 0)
	sparkle.Lifetime = NumberRange.new(0.8, 1.4)
	sparkle.Rate = 5
	sparkle.Speed = NumberRange.new(1, 2.5)
	sparkle.SpreadAngle = Vector2.new(25, 25)
	sparkle.EmissionDirection = Enum.NormalId.Top
	sparkle.Parent = marker
	marker:SetAttribute("GrassType", grassType.Id)
	marker.Parent = markers
	cell.Marker = marker
end

local function grow(cell: Cell)
	local zone = Zones.ById[cell.ZoneId]
	local grassType = rollType(cell.ZoneId)
	cell.TypeId = grassType.Id
	cell.Yield = grassType.Yield
	cell.MaxHealth = zone.GrassHealth * grassType.HealthMultiplier
	cell.Health = cell.MaxHealth
	cell.Cut = false
	setMarker(cell, grassType)
end

local function regrowLater(cell: Cell)
	local delay = GameConfig.GrassRespawnSeconds * (0.7 + rng:NextNumber() * 0.8)
	task.delay(delay, function()
		grow(cell)
		terrain:ReplaceMaterial(cell.Region, CELL, cell.MowedMaterial, TALL)
	end)
end

-- Every uncut cell whose center is inside the circle (XZ only), in zones
-- the filter allows. Only the grid squares under the circle are visited.
function GrassService.GetCellsInRadius(position: Vector3, radius: number, zoneAllowed: ((string) -> boolean)?): { Cell }
	local found = {}
	local r2 = radius * radius
	local x1, x2 = math.floor((position.X - radius) / CELL), math.floor((position.X + radius) / CELL)
	local z1, z2 = math.floor((position.Z - radius) / CELL), math.floor((position.Z + radius) / CELL)
	for ix = x1, x2 do
		for iz = z1, z2 do
			local cell = cells[ix .. "," .. iz]
			if cell and not cell.Cut then
				local dx = cell.Center.X - position.X
				local dz = cell.Center.Z - position.Z
				if dx * dx + dz * dz <= r2 and (not zoneAllowed or zoneAllowed(cell.ZoneId)) then
					table.insert(found, cell)
				end
			end
		end
	end
	return found
end

-- Applies one hit of `power`. Returns true when the cell was mowed (and
-- starts its regrowth timer); false when it only got damaged.
function GrassService.Damage(cell: Cell, power: number): boolean
	if cell.Cut then
		return false
	end
	cell.Health -= power
	if cell.Health > 0 then
		return false
	end
	cell.Cut = true
	cell.Health = 0
	if cell.Marker then
		cell.Marker:Destroy()
		cell.Marker = nil
	end
	terrain:ReplaceMaterial(cell.Region, CELL, TALL, cell.MowedMaterial)
	regrowLater(cell)
	return true
end

-- `lawnCells`: zoneId -> cell centers, from MapService.GetLawnCells().
function GrassService.Init(lawnCells: { [string]: { Vector3 } })
	paintColors()
	markers = Instance.new("Folder")
	markers.Name = "RareGrass"
	markers.Parent = Workspace

	for zoneId, centers in lawnCells do
		if not Zones.ById[zoneId] then
			continue
		end
		for _, center in centers do
			local ix, iz = math.floor(center.X / CELL), math.floor(center.Z / CELL)
			local half = Vector3.new(CELL / 2, 4, CELL / 2)
			local cell: Cell = {
				ZoneId = zoneId,
				MaxHealth = 1,
				Health = 1,
				Cut = false,
				Center = center,
				Region = Region3.new(center - half, center + half):ExpandToGrid(CELL),
				MowedMaterial = if math.floor(ix / STRIPE) % 2 == 0 then MOWED_LIGHT else MOWED_DARK,
				TypeId = "normal",
				Yield = 1,
			}
			grow(cell)
			cells[ix .. "," .. iz] = cell
			cellCount += 1
		end
	end
	if GameConfig.Verbose then
		print(("[MowIt][Grass] %d grass cells, %d rare."):format(cellCount, #markers:GetChildren()))
	end
end

return GrassService
