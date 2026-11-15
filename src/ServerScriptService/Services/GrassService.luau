--!strict
-- Grass on the lawns. "GrassArea" parts on the islands and on the personal
-- bases decide WHERE lawns are (Shared/LawnCells: cells are the terrain
-- voxel columns inside them).
--
-- The islands are shared, the grass is not: EVERY PLAYER HAS THEIR OWN
-- LAWN. What one player mows stays tall for everybody else, so a full
-- server never fights over grass and nobody's progress depends on others.
-- This service owns each player's cells as plain data (which are cut and
-- when they regrow, how damaged the standing ones are, where their rare
-- patches grow); it never touches the terrain or creates instances. Each
-- client paints its own player's lawn from what it is told here
-- (StarterPlayerScripts/GrassState): mowed cells become short striped
-- lawn in that client's terrain only, patches get their blades and
-- sparkles there.
--
-- Grass types (Shared/Config/GrassTypes.luau): most cells grow the area's
-- own grass; by luck (chances per area in MapLayout.luau `Patches`) a
-- regrown cell starts a small patch of a rarer type: Lucky Clover, Golden
-- Grass, or the next area's grass.
--
-- Cutting is grid math (a dictionary lookup per cell), never raycasts.
-- Per player only what differs from "tall, normal grass" is stored.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)
local GameConfig = require(Shared.Config.GameConfig)
local GrassTypes = require(Shared.Config.GrassTypes)
local MapLayout = require(Shared.Config.MapLayout)
local LawnCells = require(Shared.LawnCells)

local GrassService = {}

-- A lawn cell: the same for everybody.
export type Cell = {
	Key: string,
	ZoneId: string,
	Center: Vector3, -- top of the lawn at the cell's center
	Ix: number,
	Iz: number,
}

-- A rare patch cell on one player's lawn.
type Patch = { TypeId: string, Look: string, Yield: number, MaxHealth: number }

-- One player's lawn: only what differs from tall, normal, undamaged grass.
type Lawn = {
	RegrowAt: { [string]: number }, -- cut cells -> os.clock() when they stand again
	Health: { [string]: number }, -- damaged standing cells -> health left (of the blade being cut)
	Cut: { [string]: number }, -- standing cells snipped blade by blade -> blades already gone
	Patches: { [string]: Patch },
	Pending: { [string]: GrassTypes.GrassType }, -- cut cells that regrow as a patch
}

local CELL = GameConfig.GrassCellSize or 4
local SWEEP = 0.5 -- seconds between regrowth passes
local SYNC_BATCH = 200 -- patch cells per GrassPatch message

local cells: { [string]: Cell } = {}
local cellList: { Cell } = {}
local lawns: { [Player]: Lawn } = {}
local rng = Random.new()
local cutRemote: RemoteEvent
local trimRemote: RemoteEvent
local patchRemote: RemoteEvent

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

-- What a cell of this grass type is on this island: look, yield, health.
local function patchOf(cell: Cell, grassType: GrassTypes.GrassType): Patch
	local zone = Zones.ById[cell.ZoneId]
	local health, look, yield = zone.GrassHealth, cell.ZoneId, grassType.Yield
	if grassType.Id == "next" then
		local nextId = nextZoneId(cell.ZoneId)
		local nextZone = nextId and Zones.ById[nextId]
		if nextZone then
			health, look = nextZone.GrassHealth, nextZone.Id
			yield = math.max(grassType.Yield, math.round(nextZone.GrassValue / zone.GrassValue))
		end
	elseif grassType.Look then
		look = grassType.Look
	end
	return { TypeId = grassType.Id, Look = look, Yield = yield, MaxHealth = health * grassType.HealthMultiplier }
end

-- Patch changes of one pass, sent to the client in one message.
type Changes = { Centers: { Vector3 }, Types: { string }, Looks: { string } }

local function newChanges(): Changes
	return { Centers = {}, Types = {}, Looks = {} }
end

local function setPatch(lawn: Lawn, cell: Cell, grassType: GrassTypes.GrassType?, changes: Changes)
	local patch = if grassType and grassType.Id ~= "normal" then patchOf(cell, grassType) else nil
	if not patch and not lawn.Patches[cell.Key] then
		return
	end
	lawn.Patches[cell.Key] = patch
	lawn.Health[cell.Key] = nil
	table.insert(changes.Centers, cell.Center)
	table.insert(changes.Types, if patch then patch.TypeId else "")
	table.insert(changes.Looks, if patch then patch.Look else "")
end

local function send(player: Player, changes: Changes)
	for from = 1, #changes.Centers, SYNC_BATCH do
		local to = math.min(from + SYNC_BATCH - 1, #changes.Centers)
		patchRemote:FireClient(player, table.move(changes.Centers, from, to, 1, {}), table.move(changes.Types, from, to, 1, {}), table.move(changes.Looks, from, to, 1, {}))
	end
end

-- Spreads a patch type over the cells around `origin` (ragged, not round).
-- Standing normal cells change now; cut ones grow it when they regrow.
local function spreadPatch(lawn: Lawn, origin: Cell, grassType: GrassTypes.GrassType, changes: Changes)
	local r = grassType.PatchRadius
	local reach = math.ceil(r)
	for dx = -reach, reach do
		for dz = -reach, reach do
			local other = cells[LawnCells.Key(origin.Ix + dx, origin.Iz + dz)]
			local inside = dx * dx + dz * dz <= r * r and rng:NextNumber() < 0.85
			if other and other ~= origin and inside and other.ZoneId == origin.ZoneId and not lawn.Patches[other.Key] then
				if lawn.RegrowAt[other.Key] then
					lawn.Pending[other.Key] = grassType
				else
					setPatch(lawn, other, grassType, changes)
				end
			end
		end
	end
end

-- A cell stands again (or for the first time): by luck it starts a patch.
local function grow(lawn: Lawn, cell: Cell, changes: Changes)
	lawn.RegrowAt[cell.Key] = nil
	lawn.Health[cell.Key] = nil
	lawn.Cut[cell.Key] = nil
	local pending = lawn.Pending[cell.Key]
	lawn.Pending[cell.Key] = nil
	if pending then
		setPatch(lawn, cell, pending, changes)
		return
	end
	local patch = rollPatch(cell.ZoneId)
	setPatch(lawn, cell, patch, changes)
	if patch then
		spreadPatch(lawn, cell, patch, changes)
	end
end

local function maxHealth(lawn: Lawn, cell: Cell): number
	local patch = lawn.Patches[cell.Key]
	return if patch then patch.MaxHealth else Zones.ById[cell.ZoneId].GrassHealth
end

-- Every cell standing on this player's lawn whose center is inside the
-- circle (XZ only), in zones the filter allows. Only the grid squares
-- under the circle are visited.
function GrassService.GetCellsInRadius(player: Player, position: Vector3, radius: number, zoneAllowed: ((string) -> boolean)?): { Cell }
	local found = {}
	local lawn = lawns[player]
	if not lawn then
		return found
	end
	local r2 = radius * radius
	local x1, x2 = math.floor((position.X - radius) / CELL), math.floor((position.X + radius) / CELL)
	local z1, z2 = math.floor((position.Z - radius) / CELL), math.floor((position.Z + radius) / CELL)
	for ix = x1, x2 do
		for iz = z1, z2 do
			local cell = cells[ix .. "," .. iz]
			if cell and not lawn.RegrowAt[cell.Key] then
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

-- Applies one hit of `power` to a cell of this player's lawn. Returns the
-- grass it yields when that mowed it (it then regrows on its own), or nil
-- when it only got damaged. Call GrassService.Flush(player) after a batch
-- of hits, so the client hears about all of them at once.
type Batch = { Centers: { Vector3 }, Delays: { number }, TrimCenters: { Vector3 }, TrimCut: { number } }
local pendingCuts: { [Player]: Batch } = {}

local function batchOf(player: Player): Batch
	local batch = pendingCuts[player]
	if not batch then
		batch = { Centers = {}, Delays = {}, TrimCenters = {}, TrimCut = {} }
		pendingCuts[player] = batch
	end
	return batch
end

local function yieldOf(lawn: Lawn, cell: Cell): number
	local patch = lawn.Patches[cell.Key]
	return if patch then patch.Yield else GrassTypes.ById.normal.Yield
end

-- Blades standing in a whole cell of this grass (its look; GrassTufts
-- draws the same number).
local function bladesIn(lawn: Lawn, cell: Cell): number
	local patch = lawn.Patches[cell.Key]
	local look = GrassTypes.Looks[if patch then patch.Look else cell.ZoneId]
	return if look then look.Blades else 1
end

-- The cell is mowed: it regrows on its own after a while.
local function mow(player: Player, lawn: Lawn, cell: Cell)
	lawn.Health[cell.Key] = nil
	lawn.Cut[cell.Key] = nil
	lawn.Patches[cell.Key] = nil -- the client drops the patch's blades with the cut
	local delay = GameConfig.GrassRespawnSeconds * (0.7 + rng:NextNumber() * 0.8)
	lawn.RegrowAt[cell.Key] = os.clock() + delay
	local batch = batchOf(player)
	table.insert(batch.Centers, cell.Center)
	table.insert(batch.Delays, delay)
end

function GrassService.Damage(player: Player, cell: Cell, power: number): number?
	local lawn = lawns[player]
	if not lawn or lawn.RegrowAt[cell.Key] then
		return nil
	end
	local health = (lawn.Health[cell.Key] or maxHealth(lawn, cell)) - power
	if health > 0 then
		lawn.Health[cell.Key] = health
		return nil
	end
	local yield = yieldOf(lawn, cell)
	mow(player, lawn, cell)
	return yield
end

-- One hit of `power` to a single blade of the cell (tools with `Blades`,
-- Config/Tools). Returns the grass that blade yields when the hit snipped
-- it, or nil when it only got damaged, and whether the cell still stands.
-- The cell's last blade mows the cell, like Damage.
function GrassService.DamageBlade(player: Player, cell: Cell, power: number): (number?, boolean)
	local lawn = lawns[player]
	if not lawn or lawn.RegrowAt[cell.Key] then
		return nil, false
	end
	local health = (lawn.Health[cell.Key] or maxHealth(lawn, cell)) - power
	if health > 0 then
		lawn.Health[cell.Key] = health
		return nil, true
	end
	local blades = bladesIn(lawn, cell)
	local yield = math.max(1, math.round(yieldOf(lawn, cell) / blades))
	local cut = (lawn.Cut[cell.Key] or 0) + 1
	if cut >= blades then
		mow(player, lawn, cell)
		return yield, false
	end
	lawn.Cut[cell.Key] = cut
	lawn.Health[cell.Key] = nil -- the next blade is whole
	local batch = batchOf(player)
	table.insert(batch.TrimCenters, cell.Center)
	table.insert(batch.TrimCut, cut)
	return yield, true
end

-- Tells the client which cells the hits since the last Flush mowed, and
-- which lost single blades.
function GrassService.Flush(player: Player)
	local batch = pendingCuts[player]
	if batch then
		pendingCuts[player] = nil
		if #batch.TrimCenters > 0 then
			trimRemote:FireClient(player, batch.TrimCenters, batch.TrimCut)
		end
		if #batch.Centers > 0 then
			cutRemote:FireClient(player, batch.Centers, batch.Delays)
		end
	end
end

-- A fresh lawn for a player: everything tall, patches rolled by luck.
local function plant(player: Player)
	local lawn: Lawn = { RegrowAt = {}, Health = {}, Cut = {}, Patches = {}, Pending = {} }
	lawns[player] = lawn
	local changes = newChanges()
	for _, cell in cellList do
		if not lawn.Patches[cell.Key] then -- a neighbour's patch may have reached it
			grow(lawn, cell, changes)
		end
	end
	-- The client asks for its patches when it is ready to draw (GrassSync).
end

-- Everything the client needs to draw this player's lawn from scratch.
local function sync(player: Player)
	local lawn = lawns[player]
	if not lawn then
		return
	end
	local changes = newChanges()
	for key, patch in lawn.Patches do
		table.insert(changes.Centers, cells[key].Center)
		table.insert(changes.Types, patch.TypeId)
		table.insert(changes.Looks, patch.Look)
	end
	send(player, changes)
	local now = os.clock()
	local centers, delays = {}, {}
	for key, at in lawn.RegrowAt do
		table.insert(centers, cells[key].Center)
		table.insert(delays, math.max(at - now, 0))
	end
	if #centers > 0 then
		cutRemote:FireClient(player, centers, delays)
	end
	local trimCenters, trimCut = {}, {}
	for key, cut in lawn.Cut do
		table.insert(trimCenters, cells[key].Center)
		table.insert(trimCut, cut)
	end
	if #trimCenters > 0 then
		trimRemote:FireClient(player, trimCenters, trimCut)
	end
end

function GrassService.Init(remotes: Folder)
	cutRemote = remotes:WaitForChild("GrassCut") :: RemoteEvent
	patchRemote = remotes:WaitForChild("GrassPatch") :: RemoteEvent
	trimRemote = remotes:WaitForChild("GrassTrim") :: RemoteEvent
	if not Workspace.Terrain.Decoration then
		-- Decoration can't be set from a script at runtime: it is on in the
		-- project file and must be saved in the place (Terrain > Decoration).
		warn("[MowIt][Grass] Workspace.Terrain.Decoration is off: lawns will look flat.")
	end

	local terrain = Workspace.Terrain
	for index, lawn in LawnCells.Collect() do
		if Zones.ById[lawn.ZoneId] then
			local key = LawnCells.Key(lawn.Ix, lawn.Iz)
			local cell: Cell = { Key = key, ZoneId = lawn.ZoneId, Center = lawn.Center, Ix = lawn.Ix, Iz = lawn.Iz }
			cells[key] = cell
			table.insert(cellList, cell)
			-- Hand-moved lawns (and lawns saved while mowed): make sure the
			-- ground under them is tall grass. Once, before anybody plays.
			local region = LawnCells.Region(lawn.Center)
			terrain:ReplaceMaterial(region, CELL, Enum.Material.LeafyGrass, LawnCells.Tall)
			terrain:ReplaceMaterial(region, CELL, LawnCells.Mowed(lawn.Ix), LawnCells.Tall)
			if index % 400 == 0 then
				task.wait()
			end
		end
	end

	Players.PlayerAdded:Connect(plant)
	for _, player in Players:GetPlayers() do
		plant(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lawns[player] = nil
		pendingCuts[player] = nil
	end)
	local lastSync: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any;
	(remotes:WaitForChild("GrassSync") :: RemoteEvent).OnServerEvent:Connect(function(player)
		local now = os.clock()
		if now - (lastSync[player] or -math.huge) >= 2 then
			lastSync[player] = now
			sync(player)
		end
	end)

	-- Regrowth: cut cells whose time has come stand again.
	task.spawn(function()
		while true do
			task.wait(SWEEP)
			local now = os.clock()
			for player, lawn in lawns do
				local changes = newChanges()
				for key, at in lawn.RegrowAt do
					if at <= now then
						grow(lawn, cells[key], changes)
					end
				end
				send(player, changes)
			end
		end
	end)
	if GameConfig.Verbose then
		print(("[MowIt][Grass] %d grass cells, one lawn per player."):format(#cellList))
	end
end

return GrassService
