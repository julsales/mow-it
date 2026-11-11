--!strict
-- Builds the land from Shared/Config/MapLayout.luau when the place has no
-- Workspace/Zones yet (a real Studio-built map can replace it later; the
-- contract names stay the same: Zones/<id>/ZoneGate, SellPad, ...).
--
-- Order matters, each step avoids what the previous ones placed:
--   geometry -> hubs/stalls -> paths -> props -> lawn cells -> terrain ->
--   fences/walls/gates -> trees -> forest/hills -> spawn.
-- Everything random comes from one seeded Random, so every server builds
-- the same land.
--
-- Terrain (no ground parts): wild ground is LeafyGrass (short), lawns are
-- Grass (tall blades = "mow me"), paths are Sand. GrassService owns the
-- lawn cells after this.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MapLayout = require(Shared.Config.MapLayout)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Format)

local Props = require(script.Parent.Map.Props)
local Geo = require(script.Parent.Map.MapGeometry)

local MapService = {}

local CELL = 4 -- Terrain voxel; lawn cells are one voxel column
local GROUND_TOP = Props.GroundTop
local COLORS = Props.Colors
local terrain = Workspace.Terrain

MapService.Materials = {
	Wild = Enum.Material.LeafyGrass,
	Lawn = Enum.Material.Grass,
	Path = Enum.Material.Sand,
}

export type LawnCells = { [string]: { Vector3 } } -- zoneId -> cell centers (at lawn top)

local lawnCells: LawnCells = {}

-- Grid helpers ----------------------------------------------------------------

local function key(x: number, z: number): string
	return math.floor(x / CELL) .. "," .. math.floor(z / CELL)
end

local function cellCenter(ix: number, iz: number): Vector3
	return Vector3.new(ix * CELL + CELL / 2, GROUND_TOP, iz * CELL + CELL / 2)
end

local function columnRegion(center: Vector3): Region3
	local half = Vector3.new(CELL / 2, 4, CELL / 2)
	return Region3.new(center - half, center + half):ExpandToGrid(CELL)
end

-- Marks every grid cell within `radius` of a point.
local function markDisc(set: { [string]: boolean }, point: Vector3, radius: number)
	for dx = -radius, radius, CELL / 2 do
		for dz = -radius, radius, CELL / 2 do
			if dx * dx + dz * dz <= radius * radius then
				set[key(point.X + dx, point.Z + dz)] = true
			end
		end
	end
end

-- Paths -----------------------------------------------------------------------

-- A gently curving line from a to b (quadratic Bezier with a sideways bend).
local function curve(a: Vector3, b: Vector3, rng: Random): { Vector3 }
	local mid = (a + b) / 2
	local along = b - a
	local side = Vector3.new(-along.Z, 0, along.X).Unit
	local control = mid + side * (rng:NextNumber() - 0.5) * along.Magnitude * 0.5
	local points = {}
	local steps = math.max(4, math.ceil(along.Magnitude / 2))
	for i = 0, steps do
		local t = i / steps
		table.insert(points, a:Lerp(control, t):Lerp(control:Lerp(b, t), t))
	end
	return points
end

-- Props placement ----------------------------------------------------------------

type Placed = { Position: Vector3, Radius: number }

local function isClear(point: Vector3, radius: number, placed: { Placed }, blocked: { [string]: boolean }): boolean
	for _, other in placed do
		if (other.Position - point).Magnitude < other.Radius + radius + 3 then
			return false
		end
	end
	for dx = -radius, radius, CELL do
		for dz = -radius, radius, CELL do
			if blocked[key(point.X + dx, point.Z + dz)] then
				return false
			end
		end
	end
	return true
end

-- Finds a free spot in an area for something of `radius`, or nil.
local function findSpot(areaId: string, def, radius: number, rng: Random, placed: { Placed }, blocked: { [string]: boolean }, near: Vector3?, nearRadius: number?): Vector3?
	for _ = 1, 60 do
		local point: Vector3?
		if near then
			local a = rng:NextNumber() * math.pi * 2
			local d = rng:NextNumber() * (nearRadius or 16)
			point = near + Vector3.new(math.cos(a), 0, math.sin(a)) * d
		else
			point = Geo.RandomPointIn(areaId, def, rng)
		end
		if point and Geo.FitsIn(point, radius + 2, areaId) and isClear(point, radius, placed, blocked) then
			return point
		end
	end
	return nil
end

-- Props face the area's hub (+Z of the prop frame points at it).
local function facing(point: Vector3, target: Vector3): CFrame
	local ground = Vector3.new(point.X, GROUND_TOP, point.Z)
	local away = Vector3.new(point.X - target.X, 0, point.Z - target.Z)
	if away.Magnitude < 0.1 then
		away = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(ground, ground + away.Unit)
end

-- Fences, invisible walls and gates ------------------------------------------------

local function laterZone(a: string?, b: string?): string?
	if not a or not b then
		return nil -- the outer edge: always walled
	end
	return if (Geo.Order[a] or 0) >= (Geo.Order[b] or 0) then a else b
end

local function buildBorders(land: Instance, zoneFolders: { [string]: Folder }, gates: { { Point: Vector3, ZoneId: string } })
	local fences = Props.model("Fences", land)
	local perimeter = Instance.new("Folder")
	perimeter.Name = "PerimeterWalls"
	perimeter.Parent = land
	local halfGate = MapLayout.GateWidth / 2

	local function nearGate(point: Vector3): boolean
		for _, gate in gates do
			if (gate.Point - point).Magnitude < halfGate then
				return true
			end
		end
		return false
	end

	for _, line in Geo.BorderLines() do
		for i = 1, #line do
			local p = line[i]
			if not nearGate(p) then
				Props.make("Post", fences, {
					Size = Vector3.new(0.9, 4.2, 0.9),
					CFrame = CFrame.new(p.X, GROUND_TOP + 2.1, p.Z),
					Color = COLORS.Fence,
					Material = Enum.Material.Wood,
				})
			end
			local q = line[i + 1]
			if not q then
				continue
			end
			local mid = (p + q) / 2
			if nearGate(mid) or nearGate(p) or nearGate(q) then
				continue
			end
			local length = (q - p).Magnitude
			local frame = CFrame.lookAt(Vector3.new(mid.X, 0, mid.Z), Vector3.new(q.X, 0, q.Z))
			for _, height in { 1.5, 3.2 } do
				Props.make("Rail", fences, {
					Size = Vector3.new(0.3, 0.5, length),
					CFrame = frame + Vector3.new(0, GROUND_TOP + height, 0),
					Color = COLORS.Fence,
					Material = Enum.Material.Wood,
				})
			end
			-- Invisible wall above the fence; it belongs to the later area of
			-- the two sides, and that player's client drops it once unlocked.
			local normal = frame.RightVector
			local zoneId = laterZone(Geo.AreaAt(mid + normal * 3), Geo.AreaAt(mid - normal * 3))
			local wall = Props.make("ZoneWall", if zoneId then zoneFolders[zoneId] else perimeter, {
				Size = Vector3.new(0.6, MapLayout.WallHeight, length + 0.5),
				CFrame = frame + Vector3.new(0, GROUND_TOP + MapLayout.WallHeight / 2, 0),
				Color = COLORS.Fence,
				Transparency = 1,
			})
			wall.CastShadow = false
			wall.CanQuery = false
			if zoneId then
				wall:SetAttribute("ZoneId", zoneId)
			end
		end
	end

	-- Gates: contract part Zones/<id>/ZoneGate (solid; clients open the ones
	-- their player unlocked, see Main.client.luau).
	for _, gate in gates do
		local zone = Zones.ById[gate.ZoneId]
		local angle = Geo.Polar(gate.Point)
		-- Orient along the border: tangent for ring borders, radial otherwise.
		local def = MapLayout.Areas[gate.ZoneId]
		local onRing = false
		for _, radius in MapLayout.RingRadius do
			if def.Gate and radius == def.Gate.Radius then
				onRing = true
			end
		end
		local along = if onRing then Geo.Direction(angle + 90) else Geo.Direction(angle)
		local frame = CFrame.lookAt(gate.Point, gate.Point + along) * CFrame.Angles(0, math.rad(90), 0)
		local part = Props.make("ZoneGate", zoneFolders[gate.ZoneId], {
			Size = Vector3.new(MapLayout.GateWidth, MapLayout.WallHeight, 0.6),
			CFrame = frame + Vector3.new(0, GROUND_TOP + MapLayout.WallHeight / 2, 0),
			Color = zone.ThemeColor,
			Material = Enum.Material.Glass,
			Transparency = 0.35,
		})
		local text = ("LOCKED\n%s\n%s · Lv %d"):format(zone.DisplayName, Format.Coins(zone.UnlockPrice), zone.RequiredLevel)
		Props.label(part, Enum.NormalId.Front, text, Color3.new(1, 1, 1))
		Props.label(part, Enum.NormalId.Back, text, Color3.new(1, 1, 1))
	end
end

-- Build ---------------------------------------------------------------------------

local function buildSpawn()
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "GameSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.Position = Vector3.new(0, GROUND_TOP + 0.2, 6)
	spawn.Color = COLORS.Path
	spawn.Material = Enum.Material.Concrete
	spawn.Duration = 0
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = Workspace
end

function MapService.BuildIfMissing()
	if Workspace:FindFirstChild("Zones") then
		return
	end
	Props.BuildAmbience()
	local template = Workspace:FindFirstChild("SpawnLocation")
	if template and template:IsA("SpawnLocation") then
		template:Destroy() -- Studio Baseplate template spawn
	end
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy() -- the terrain is the ground now (runtime only)
	end

	local rng = Random.new(MapLayout.Seed)
	local land = Props.model("Land", Workspace)
	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	local zoneFolders: { [string]: Folder } = {}
	for _, zone in Zones.List do
		local folder = Instance.new("Folder")
		folder.Name = zone.Id
		folder.Parent = zonesFolder
		zoneFolders[zone.Id] = folder
	end

	-- 1. Hubs, gates, stalls (cells under them are blocked for lawns).
	local blocked: { [string]: boolean } = {}
	local pathCells: { [string]: boolean } = {}
	local placed: { [string]: { Placed } } = {}
	local hubs: { [string]: Vector3 } = {}
	local gates = {}
	for _, zone in Zones.List do
		local def = MapLayout.Areas[zone.Id]
		if def then
			hubs[zone.Id] = Geo.Hub(def)
			placed[zone.Id] = {}
			local gatePoint = Geo.GatePoint(def)
			if gatePoint then
				table.insert(gates, { Point = gatePoint, ZoneId = zone.Id })
			end
		end
	end

	-- 2. Paths: from the area behind each gate, through the gate, to the hub.
	local pathMarks: { Vector3 } = {}
	for _, gate in gates do
		-- The area on the other side of the gate: probe across the border
		-- both radially and sideways (ring borders vs sector borders).
		local toId = gate.ZoneId
		local radial = Geo.Direction((Geo.Polar(gate.Point)))
		local tangent = Vector3.new(-radial.Z, 0, radial.X)
		local fromId: string? = nil
		for _, probe in { radial, -radial, tangent, -tangent } do
			local id = Geo.AreaAt(gate.Point + probe * 7)
			if id and id ~= toId then
				fromId = id
				break
			end
		end
		local fromHub = fromId and hubs[fromId] or Vector3.zero
		for _, segment in { curve(fromHub, gate.Point, rng), curve(gate.Point, hubs[toId], rng) } do
			for _, point in segment do
				markDisc(pathCells, point, MapLayout.PathWidth / 2)
				table.insert(pathMarks, point)
			end
		end
	end
	for k in pathCells do
		blocked[k] = true
	end

	-- 3. Per-area buildings: stall + shop near the hub, sign near the gate,
	-- then the area's props, all irregular and facing the hub.
	local dressing = Props.model("Dressing", land)
	for _, zone in Zones.List do
		local def = MapLayout.Areas[zone.Id]
		if not def then
			warn(("[MowIt][Map] No MapLayout row for zone %q."):format(zone.Id))
			continue
		end
		local hub = hubs[zone.Id]
		local list = placed[zone.Id]
		local function place(radius: number, build: (CFrame) -> (), near: Vector3?, nearRadius: number?)
			local spot = findSpot(zone.Id, def, radius, rng, list, blocked, near, nearRadius)
			if spot then
				table.insert(list, { Position = spot, Radius = radius })
				markDisc(blocked, spot, radius + MapLayout.LawnMargin / 2)
				build(facing(spot, hub))
			end
		end
		place(9, function(cf)
			Props.sellPad(zoneFolders[zone.Id], cf, 0, 0)
		end, hub, 22)
		place(9, function(cf)
			Props.shop(dressing, cf, 0, 0, zone.ThemeColor)
		end, hub, 26)
		for _, gate in gates do
			if gate.ZoneId == zone.Id then
				place(9, function(cf)
					Props.sign(dressing, cf, 0, 0, ("%s\n%s"):format(zone.DisplayName, zone.Subtitle), zone.ThemeColor)
				end, gate.Point, 18)
			end
		end
		for _, name in def.Props do
			local kind = Props.Kinds[name]
			if kind then
				place(kind.Radius, function(cf)
					kind.Build(dressing, cf)
				end)
			else
				warn(("[MowIt][Map] Unknown prop %q in MapLayout (zone %s)."):format(name, zone.Id))
			end
		end
	end

	-- 4. Lawns: blobs inside each area, clear of borders, paths and props.
	local blobs: { [string]: { { Center: Vector3, Radius: number } } } = {}
	for _, zone in Zones.List do
		local def = MapLayout.Areas[zone.Id]
		if def then
			blobs[zone.Id] = {}
			for _ = 1, def.Lawns.Count do
				local center = Geo.RandomPointIn(zone.Id, def, rng)
				if center and (center - hubs[zone.Id]).Magnitude > 14 then
					local radius = def.Lawns.MinRadius + rng:NextNumber() * (def.Lawns.MaxRadius - def.Lawns.MinRadius)
					-- Two overlapping discs per blob: lumpy, not round.
					table.insert(blobs[zone.Id], { Center = center, Radius = radius })
					local a = rng:NextNumber() * math.pi * 2
					table.insert(blobs[zone.Id], {
						Center = center + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * 0.7,
						Radius = radius * (0.5 + rng:NextNumber() * 0.4),
					})
				end
			end
		end
	end
	local extent = MapLayout.RingRadius[Geo.LastRing] + MapLayout.RingWobble
	local count = 0
	for ix = math.floor(-extent / CELL), math.ceil(extent / CELL) do
		for iz = math.floor(-extent / CELL), math.ceil(extent / CELL) do
			local center = cellCenter(ix, iz)
			local zoneId = Geo.AreaAt(center)
			if not zoneId or blocked[ix .. "," .. iz] then
				continue
			end
			local inBlob = false
			for _, blob in blobs[zoneId] or {} do
				if (Vector3.new(center.X, 0, center.Z) - Vector3.new(blob.Center.X, 0, blob.Center.Z)).Magnitude <= blob.Radius then
					inBlob = true
					break
				end
			end
			if inBlob and Geo.FitsIn(center, MapLayout.LawnMargin / 2, zoneId) then
				lawnCells[zoneId] = lawnCells[zoneId] or {}
				table.insert(lawnCells[zoneId], center)
				count += 1
			end
		end
	end

	-- 5. Terrain: one slab of wild ground, then lawns and paths painted in.
	-- Round ground (one full voxel layer, top exactly at GROUND_TOP); its
	-- edge hides behind the rim hills built in step 8.
	terrain:FillCylinder(CFrame.new(0, GROUND_TOP - 4, 0), 4, MapLayout.ForestOuterRadius + 40, MapService.Materials.Wild)
	local painted = 0
	for _, cells in lawnCells do
		for _, center in cells do
			terrain:ReplaceMaterial(columnRegion(center), CELL, MapService.Materials.Wild, MapService.Materials.Lawn)
			painted += 1
			if painted % 400 == 0 then
				task.wait()
			end
		end
	end
	for k in pathCells do
		local ix, iz = string.match(k, "(-?%d+),(-?%d+)")
		local center = cellCenter(tonumber(ix) :: number, tonumber(iz) :: number)
		terrain:ReplaceMaterial(columnRegion(center), CELL, MapService.Materials.Wild, MapService.Materials.Path)
	end

	-- 6. Fences, invisible walls and gates.
	buildBorders(land, zoneFolders, gates)

	-- 7. Trees scattered in every area (never on lawns or paths).
	local lawnSet: { [string]: boolean } = {}
	for _, cells in lawnCells do
		for _, center in cells do
			lawnSet[key(center.X, center.Z)] = true
		end
	end
	local trees = Props.model("Trees", land)
	for _, zone in Zones.List do
		local def = MapLayout.Areas[zone.Id]
		if def then
			for _ = 1, def.Trees do
				local spot = findSpot(zone.Id, def, 4, rng, placed[zone.Id], blocked)
				if spot and not lawnSet[key(spot.X, spot.Z)] then
					table.insert(placed[zone.Id], { Position = spot, Radius = 3 })
					Props.tree(trees, CFrame.new(spot.X, GROUND_TOP, spot.Z), 0, 0, 0.8 + rng:NextNumber() * 0.6)
				end
			end
		end
	end

	-- 8. Beyond the last fence: forest and hills to the horizon.
	local landEdge = MapLayout.RingRadius[Geo.LastRing] + 14
	local forest = Props.model("Forest", land)
	for _ = 1, MapLayout.ForestTrees do
		local angle = rng:NextNumber() * 360
		local radius = landEdge + rng:NextNumber() * (MapLayout.ForestOuterRadius - landEdge - 20)
		local p = Geo.Point(angle, radius)
		Props.tree(forest, CFrame.new(p.X, GROUND_TOP, p.Z), 0, 0, 1 + rng:NextNumber() * 0.9)
	end
	for _ = 1, MapLayout.Hills do
		local angle = rng:NextNumber() * 360
		local radius = landEdge + 40 + rng:NextNumber() * (MapLayout.ForestOuterRadius - landEdge - 60)
		local hillRadius = 20 + rng:NextNumber() * 26
		local p = Geo.Point(angle, radius)
		terrain:FillBall(Vector3.new(p.X, GROUND_TOP - hillRadius * 0.55, p.Z), hillRadius, MapService.Materials.Wild)
	end

	-- Rim hills: a ring of big hills where the ground ends, so the world
	-- fades into hills and haze instead of a visible edge.
	local rimCount = 18
	for i = 1, rimCount do
		local angle = (i + rng:NextNumber() * 0.6) * 360 / rimCount
		local hillRadius = 45 + rng:NextNumber() * 25
		local p = Geo.Point(angle, MapLayout.ForestOuterRadius + 10)
		terrain:FillBall(Vector3.new(p.X, GROUND_TOP - hillRadius * 0.35, p.Z), hillRadius, MapService.Materials.Wild)
	end

	zonesFolder.Parent = Workspace
	buildSpawn()
	print(("[MowIt][Map] Land built: %d lawn cells, %d path cells, %d gates."):format(count, #pathMarks, #gates))
end

-- Lawn cell centers per zone (GrassService grows grass on them).
function MapService.GetLawnCells(): LawnCells
	return lawnCells
end

return MapService
