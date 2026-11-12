--!strict
-- Grass on the lawns. "GrassArea" parts under Workspace/Zones/<id> decide
-- WHERE lawns are (cells are the voxel columns inside them; their terrain is
-- Grass, whose 3D blades sway in the wind); this
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
	-- Terrain colors are set once by MapService (and saved with a baked
	-- map), so hand-tuned colors in Studio are never overwritten here.
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

-- Lawn cell centers from the contract parts: every 4x4 voxel column whose
-- center lies inside a "GrassArea" part under Workspace/Zones/<ZoneId>
-- (built by MapService, or baked and hand-edited in Studio). The lawn's
-- surface is the bottom of the part.
local function collectLawnCells(): { [string]: { Vector3 } }
	local result: { [string]: { Vector3 } } = {}
	local zones = Workspace:FindFirstChild("Zones")
	if not zones then
		return result
	end
	local seen: { [string]: boolean } = {}
	for _, zoneFolder in zones:GetChildren() do
		for _, part in zoneFolder:GetDescendants() do
			if part.Name ~= "GrassArea" or not part:IsA("BasePart") then
				continue
			end
			local cf, size = part.CFrame, part.Size
			local half = size / 2
			local reach = Vector3.new(size.X, 0, size.Z).Magnitude / 2
			local y = cf.Position.Y - half.Y
			for ix = math.floor((cf.X - reach) / CELL), math.floor((cf.X + reach) / CELL) do
				for iz = math.floor((cf.Z - reach) / CELL), math.floor((cf.Z + reach) / CELL) do
					local center = Vector3.new(ix * CELL + CELL / 2, y, iz * CELL + CELL / 2)
					local p = cf:PointToObjectSpace(Vector3.new(center.X, cf.Y, center.Z))
					local k = ix .. "," .. iz
					if math.abs(p.X) <= half.X and math.abs(p.Z) <= half.Z and not seen[k] then
						seen[k] = true
						result[zoneFolder.Name] = result[zoneFolder.Name] or {}
						table.insert(result[zoneFolder.Name], center)
					end
				end
			end
		end
	end
	return result
end

function GrassService.Init()
	paintColors()
	markers = Instance.new("Folder")
	markers.Name = "RareGrass"
	markers.Parent = Workspace

	for zoneId, centers in collectLawnCells() do
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
			-- Hand-moved lawns: make sure the ground under them is lawn.
			terrain:ReplaceMaterial(cell.Region, CELL, Enum.Material.LeafyGrass, TALL)
			terrain:ReplaceMaterial(cell.Region, CELL, cell.MowedMaterial, TALL)
			grow(cell)
			cells[ix .. "," .. iz] = cell
			cellCount += 1
			if cellCount % 400 == 0 then
				task.wait()
			end
		end
	end
	if GameConfig.Verbose then
		print(("[MowIt][Grass] %d grass cells, %d rare."):format(cellCount, #markers:GetChildren()))
	end
end

return GrassService
