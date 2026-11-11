--!strict
-- Grass: every lawn (Workspace/Zones/<ZoneId>/GrassArea) is covered with
-- Terrain Grass. With Terrain.Decoration on, Roblox draws dense 3D grass
-- blades that sway in the wind, for free, on every client.
--
-- Mowing = changing the Terrain material of one 4x4 voxel column ("cell"):
--   Grass (tall blades) -> LeafyGrass / Ground recolored as short lawn,
-- alternating every GrassStripeCells cells, so mowed lawns show the classic
-- light/dark stripes. Regrowth swaps the material back to Grass.
--
-- The server owns the state (health per cell, in Lua tables) and edits the
-- Terrain; Terrain edits replicate to every player on their own. Cutting is
-- grid math, not raycasts, so even huge tool radii stay cheap.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)
local GameConfig = require(Shared.Config.GameConfig)

local GrassService = {}

export type Cell = {
	ZoneId: string,
	MaxHealth: number,
	Health: number,
	Cut: boolean,
	Center: Vector3, -- top of the lawn at the cell's center
	Region: Region3,
	MowedMaterial: Enum.Material,
}

type Grid = {
	ZoneId: string,
	Origin: Vector3, -- center of cell (0, 0), at lawn top
	CountX: number,
	CountZ: number,
	Cells: { [number]: Cell }, -- index = ix * CountZ + iz (0-based ix/iz)
}

local CELL = 4 -- Terrain voxel size; GameConfig.GrassCellSize documents it
local STRIPE = GameConfig.GrassStripeCells or 2
local TALL = Enum.Material.Grass
local MOWED_LIGHT = Enum.Material.LeafyGrass
local MOWED_DARK = Enum.Material.Ground

local grids: { Grid } = {}
local terrain = Workspace.Terrain

local function paintLawnColors()
	-- Decoration (the 3D blades) can't be set from a script at runtime; it is
	-- on in the project file (default.project.json > Workspace > Terrain).
	if not terrain.Decoration then
		warn("[MowIt][Grass] Workspace.Terrain.Decoration is off: lawns will look flat.")
	end
	terrain:SetMaterialColor(TALL, Color3.fromRGB(88, 164, 58))
	terrain:SetMaterialColor(MOWED_LIGHT, Color3.fromRGB(146, 204, 92))
	terrain:SetMaterialColor(MOWED_DARK, Color3.fromRGB(104, 168, 66))
end

local function buildGrid(zoneDef, area: BasePart): number
	-- Snap the lawn to the voxel grid so every cell is exactly one column.
	local top = area.Position.Y + area.Size.Y / 2
	local minX = math.ceil((area.Position.X - area.Size.X / 2) / CELL) * CELL
	local minZ = math.ceil((area.Position.Z - area.Size.Z / 2) / CELL) * CELL
	local countX = math.max(1, math.floor((area.Position.X + area.Size.X / 2 - minX) / CELL))
	local countZ = math.max(1, math.floor((area.Position.Z + area.Size.Z / 2 - minZ) / CELL))

	-- One 2-stud slab of Grass whose top is the lawn top.
	local width, depth = countX * CELL, countZ * CELL
	terrain:FillBlock(CFrame.new(minX + width / 2, top - 1, minZ + depth / 2), Vector3.new(width, 2, depth), TALL)

	local origin = Vector3.new(minX + CELL / 2, top, minZ + CELL / 2)
	local grid: Grid = { ZoneId = zoneDef.Id, Origin = origin, CountX = countX, CountZ = countZ, Cells = {} }
	for ix = 0, countX - 1 do
		for iz = 0, countZ - 1 do
			local center = origin + Vector3.new(ix * CELL, 0, iz * CELL)
			local half = Vector3.new(CELL / 2, 4, CELL / 2)
			grid.Cells[ix * countZ + iz] = {
				ZoneId = zoneDef.Id,
				MaxHealth = zoneDef.GrassHealth,
				Health = zoneDef.GrassHealth,
				Cut = false,
				Center = center,
				Region = Region3.new(center - half, center + half):ExpandToGrid(CELL),
				MowedMaterial = if math.floor(ix / STRIPE) % 2 == 0 then MOWED_LIGHT else MOWED_DARK,
			}
		end
	end
	table.insert(grids, grid)
	return countX * countZ
end

local function regrowLater(cell: Cell)
	local delay = GameConfig.GrassRespawnSeconds * (0.7 + math.random() * 0.8)
	task.delay(delay, function()
		cell.Cut = false
		cell.Health = cell.MaxHealth
		terrain:ReplaceMaterial(cell.Region, CELL, cell.MowedMaterial, TALL)
	end)
end

-- Every uncut cell whose center is inside the circle (XZ only), in zones
-- the filter allows. Only the grid squares under the circle's bounding box
-- are visited.
function GrassService.GetCellsInRadius(position: Vector3, radius: number, zoneAllowed: ((string) -> boolean)?): { Cell }
	local found = {}
	local r2 = radius * radius
	for _, grid in grids do
		if zoneAllowed and not zoneAllowed(grid.ZoneId) then
			continue
		end
		local localX = (position.X - grid.Origin.X) / CELL
		local localZ = (position.Z - grid.Origin.Z) / CELL
		local span = radius / CELL
		local x1 = math.max(0, math.ceil(localX - span))
		local x2 = math.min(grid.CountX - 1, math.floor(localX + span))
		local z1 = math.max(0, math.ceil(localZ - span))
		local z2 = math.min(grid.CountZ - 1, math.floor(localZ + span))
		for ix = x1, x2 do
			for iz = z1, z2 do
				local dx = (ix - localX) * CELL
				local dz = (iz - localZ) * CELL
				if dx * dx + dz * dz <= r2 then
					local cell = grid.Cells[ix * grid.CountZ + iz]
					if cell and not cell.Cut then
						table.insert(found, cell)
					end
				end
			end
		end
	end
	return found
end

-- Applies one hit of `power` to a cell. Returns true when the cell was
-- mowed (and starts its regrowth timer); false when it only got damaged.
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
	terrain:ReplaceMaterial(cell.Region, CELL, TALL, cell.MowedMaterial)
	regrowLater(cell)
	return true
end

function GrassService.Init()
	paintLawnColors()
	local zonesFolder = Workspace:WaitForChild("Zones")
	local total = 0
	for _, zoneDef in Zones.List do
		local zoneFolder = zonesFolder:FindFirstChild(zoneDef.Id)
		local area = zoneFolder and zoneFolder:FindFirstChild("GrassArea")
		if area and area:IsA("BasePart") then
			total += buildGrid(zoneDef, area)
			task.wait() -- spread lawn builds over frames
		else
			warn(("[MowIt][Grass] Zone %q has no GrassArea part; no grass there."):format(zoneDef.Id))
		end
	end
	if GameConfig.Verbose then
		print(("[MowIt][Grass] %d grass cells across %d lawns."):format(total, #grids))
	end
end

return GrassService
