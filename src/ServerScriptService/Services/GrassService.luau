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
-- own grass; by luck (chances per area in MapLayout.luau `Patches`) a
-- regrown cell starts a small patch of a rarer type: Lucky Clover, Golden
-- Grass, or the next area's grass. Non-normal cells get a marker part
-- (Workspace/RareGrass, attributes GrassType + Look): clients draw their
-- blades from it, lucky/golden ones also sparkle so players can chase them.
--
-- Cutting is grid math (a dictionary lookup per cell), never raycasts.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)
local GameConfig = require(Shared.Config.GameConfig)
local GrassTypes = require(Shared.Config.GrassTypes)
local MapLayout = require(Shared.Config.MapLayout)
local LawnCells = require(Shared.LawnCells)

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
	Look: string, -- GrassTypes.Looks key the clients draw
	Yield: number, -- grass gained when this cell is cut
	Marker: BasePart?, -- for non-normal types (clients read it)
	Pending: GrassTypes.GrassType?, -- patch type to grow next time
	Ix: number,
	Iz: number,
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

-- The next area in the ladder (for "next" patches), or nil for the last.
local function nextZoneId(zoneId: string): string?
	local nextZone = Zones.List[(Zones.IndexById[zoneId] or #Zones.List) + 1]
	return nextZone and nextZone.Id
end

-- A patch type that can grow here, rolled rarest first, or nil (normal).
local function rollPatch(zoneId: string): GrassTypes.GrassType?
	local def = MapLayout.Areas[zoneId]
	if not def then
		return nil
	end
	local roll = rng:NextNumber()
	for _, typeId in GrassTypes.PatchOrder do
		local chance = def.Patches[typeId] or 0
		if typeId == "next" and not nextZoneId(zoneId) then
			chance = 0
		end
		if roll < chance then
			return GrassTypes.ById[typeId]
		end
		roll -= chance
	end
	return nil
end

local function setMarker(cell: Cell, grassType: GrassTypes.GrassType)
	if cell.Marker then
		cell.Marker:Destroy()
		cell.Marker = nil
	end
	if grassType.Id == "normal" then
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
	-- Sparkles: lucky/golden shine in their own color; next-area patches
	-- glint softly in that area's theme color.
	local look = GrassTypes.Looks[cell.Look]
	local glint = if look and look.Sparkle then look.Sparkle elseif grassType.Id == "next" and Zones.ById[cell.Look] then Zones.ById[cell.Look].ThemeColor else nil
	if glint then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(glint)
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new(0.9, 0)
		sparkle.Lifetime = NumberRange.new(0.9, 1.6)
		sparkle.Rate = if look and look.Sparkle then 4 else 1.5
		sparkle.Speed = NumberRange.new(1.5, 3.5)
		sparkle.SpreadAngle = Vector2.new(25, 25)
		sparkle.EmissionDirection = Enum.NormalId.Top
		sparkle.Parent = marker
	end
	marker:SetAttribute("GrassType", grassType.Id)
	marker:SetAttribute("Look", cell.Look)
	marker.Parent = markers
	cell.Marker = marker
end

-- Gives a standing cell its grass type: health, yield, look, marker.
local function applyType(cell: Cell, grassType: GrassTypes.GrassType)
	local zone = Zones.ById[cell.ZoneId]
	local health, value, look = zone.GrassHealth, zone.GrassValue, cell.ZoneId
	local yield = grassType.Yield
	if grassType.Id == "next" then
		local nextId = nextZoneId(cell.ZoneId)
		local nextZone = nextId and Zones.ById[nextId]
		if nextZone then
			health, look = nextZone.GrassHealth, nextZone.Id
			yield = math.max(grassType.Yield, math.round(nextZone.GrassValue / value))
		end
	elseif grassType.Look then
		look = grassType.Look
	end
	cell.TypeId = grassType.Id
	cell.Look = look
	cell.Yield = yield
	cell.MaxHealth = health * grassType.HealthMultiplier
	cell.Health = cell.MaxHealth
	setMarker(cell, grassType)
end

-- Spreads a patch type over the cells around `origin` (ragged, not round).
-- Standing normal cells change now; cut ones grow it when they regrow.
local function spreadPatch(origin: Cell, grassType: GrassTypes.GrassType)
	local r = grassType.PatchRadius
	local reach = math.ceil(r)
	for dx = -reach, reach do
		for dz = -reach, reach do
			local other = cells[LawnCells.Key(origin.Ix + dx, origin.Iz + dz)]
			local inside = dx * dx + dz * dz <= r * r and rng:NextNumber() < 0.85
			if other and other ~= origin and inside and other.ZoneId == origin.ZoneId and other.TypeId == "normal" then
				if other.Cut then
					other.Pending = grassType
				else
					applyType(other, grassType)
				end
			end
		end
	end
end

local function grow(cell: Cell)
	cell.Cut = false
	local pending = cell.Pending
	cell.Pending = nil
	if pending then
		applyType(cell, pending)
		return
	end
	local patch = rollPatch(cell.ZoneId)
	applyType(cell, patch or GrassTypes.ById.normal)
	if patch then
		spreadPatch(cell, patch)
	end
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

function GrassService.Init()
	paintColors()
	markers = Instance.new("Folder")
	markers.Name = "RareGrass"
	markers.Parent = Workspace

	-- Create every cell first, then grow them, so patches can spread over
	-- their neighbours.
	local created: { Cell } = {}
	for _, lawn in LawnCells.Collect(Workspace:FindFirstChild("Zones")) do
		if not Zones.ById[lawn.ZoneId] then
			continue
		end
		local zoneId, center, ix, iz = lawn.ZoneId, lawn.Center, lawn.Ix, lawn.Iz
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
			Look = zoneId,
			Yield = 1,
			Ix = ix,
			Iz = iz,
		}
		-- Hand-moved lawns: make sure the ground under them is lawn.
		terrain:ReplaceMaterial(cell.Region, CELL, Enum.Material.LeafyGrass, TALL)
		terrain:ReplaceMaterial(cell.Region, CELL, cell.MowedMaterial, TALL)
		cells[LawnCells.Key(ix, iz)] = cell
		table.insert(created, cell)
		cellCount += 1
		if cellCount % 400 == 0 then
			task.wait()
		end
	end
	for _, cell in created do
		if cell.TypeId == "normal" then -- a neighbour's patch may have reached it
			grow(cell)
		end
	end
	if GameConfig.Verbose then
		print(("[MowIt][Grass] %d grass cells, %d rare."):format(cellCount, #markers:GetChildren()))
	end
end

return GrassService
