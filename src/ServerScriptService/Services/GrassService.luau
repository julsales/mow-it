--!strict
-- Grass: every lawn (Workspace/Zones/<ZoneId>/GrassArea) is covered by a
-- grid of grass cells, so lawns look full instead of dotted with tufts.
--
-- Split of work (roblox-networking: replicate state, not animation):
--   * Server owns the STATE of each cell: attributes Health and Cut on an
--     anchored Part tagged "GrassCell". It never moves or resizes cells
--     after creating them.
--   * Clients own the LOOK (GrassVisuals.client.luau): they shrink cut
--     cells to stubble, draw blades, animate regrowth and burst clippings.
--     So a cut costs two attribute changes on the wire, not a tween.
--
-- Cells are invisible to physics (no collide/query/touch) and cutting is
-- grid math, not raycasts, so even huge tool radii stay cheap.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)
local GameConfig = require(Shared.Config.GameConfig)

local GrassService = {}

export type Cell = {
	Part: BasePart,
	ZoneId: string,
	MaxHealth: number,
	Health: number,
	Cut: boolean,
}

type Grid = {
	ZoneId: string,
	Origin: Vector3, -- world position of cell (0, 0)'s center, at lawn top
	CountX: number,
	CountZ: number,
	Cells: { [number]: Cell }, -- index = ix * CountZ + iz (0-based ix/iz)
}

local grids: { Grid } = {}
local container: Folder

local CELL = GameConfig.GrassCellSize

local function makeCell(zoneDef, grid: Grid, ix: number, iz: number): Cell
	local height = GameConfig.GrassTallHeight * (0.85 + math.random() * 0.3)
	local center = grid.Origin + Vector3.new(ix * CELL, 0, iz * CELL)

	local part = Instance.new("Part")
	part.Name = "GrassCell"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false -- thousands alive; shadows cost more than they add
	part.Material = Enum.Material.Grass
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	-- Slight shade noise so a field doesn't read as one flat color.
	part.Color = zoneDef.GrassColor:Lerp(Color3.new(0, 0, 0), math.random() * 0.12)
	part.Size = Vector3.new(CELL, height, CELL)
	part.CFrame = CFrame.new(center + Vector3.new(0, height / 2, 0))
	part:SetAttribute("ZoneId", zoneDef.Id)
	part:SetAttribute("MaxHealth", zoneDef.GrassHealth)
	part:SetAttribute("Health", zoneDef.GrassHealth)
	part:SetAttribute("Cut", false)
	CollectionService:AddTag(part, "GrassCell")
	part.Parent = container

	return { Part = part, ZoneId = zoneDef.Id, MaxHealth = zoneDef.GrassHealth, Health = zoneDef.GrassHealth, Cut = false }
end

local function buildGrid(zoneDef, area: BasePart)
	-- Fit as many whole cells as the lawn holds, centered on it.
	local countX = math.max(1, math.floor(area.Size.X / CELL))
	local countZ = math.max(1, math.floor(area.Size.Z / CELL))
	local top = area.Position.Y + area.Size.Y / 2
	local origin = Vector3.new(
		area.Position.X - (countX - 1) * CELL / 2,
		top,
		area.Position.Z - (countZ - 1) * CELL / 2
	)
	local grid: Grid = { ZoneId = zoneDef.Id, Origin = origin, CountX = countX, CountZ = countZ, Cells = {} }
	for ix = 0, countX - 1 do
		for iz = 0, countZ - 1 do
			grid.Cells[ix * countZ + iz] = makeCell(zoneDef, grid, ix, iz)
		end
		if ix % 8 == 7 then
			task.wait() -- spread the build over frames instead of one long hitch
		end
	end
	table.insert(grids, grid)
	return countX * countZ
end

local function regrowLater(cell: Cell)
	local delay = GameConfig.GrassRespawnSeconds * (0.7 + math.random() * 0.8)
	task.delay(delay, function()
		if not cell.Part.Parent then
			return
		end
		cell.Cut = false
		cell.Health = cell.MaxHealth
		cell.Part:SetAttribute("Health", cell.MaxHealth)
		cell.Part:SetAttribute("Cut", false)
	end)
end

-- Every uncut cell whose center is inside the circle (XZ only), in zones
-- the filter allows. Cheap: only the grid squares under the circle's
-- bounding box are visited.
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
-- cut down (and starts its regrowth timer); false when it only got shorter.
function GrassService.Damage(cell: Cell, power: number): boolean
	if cell.Cut then
		return false
	end
	cell.Health -= power
	if cell.Health > 0 then
		cell.Part:SetAttribute("Health", cell.Health)
		return false
	end
	cell.Cut = true
	cell.Health = 0
	cell.Part:SetAttribute("Health", 0)
	cell.Part:SetAttribute("Cut", true)
	regrowLater(cell)
	return true
end

function GrassService.Init()
	container = Instance.new("Folder")
	container.Name = "Grass"
	container.Parent = Workspace

	local zonesFolder = Workspace:WaitForChild("Zones")
	local total = 0
	for _, zoneDef in Zones.List do
		local zoneFolder = zonesFolder:FindFirstChild(zoneDef.Id)
		local area = zoneFolder and zoneFolder:FindFirstChild("GrassArea")
		if area and area:IsA("BasePart") then
			total += buildGrid(zoneDef, area)
		else
			warn(("[MowIt][Grass] Zone %q has no GrassArea part; no grass there."):format(zoneDef.Id))
		end
	end
	if GameConfig.Verbose then
		print(("[MowIt][Grass] %d grass cells across %d lawns."):format(total, #grids))
	end
end

return GrassService
