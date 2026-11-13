--!strict
-- Builds the land from Shared/Config/MapLayout.luau when the place has no
-- Workspace/Zones yet (a baked or hand-built map replaces it; the contract
-- names stay the same: Zones/<id>/ZoneGate, SellPad, GrassArea, ...).
--
-- The land is a farm road (see MapLayout.luau): areas follow each other
-- along one winding road, lawns are big fields on both sides of it, one
-- fence line with a gate crosses the land between two areas, and the land
-- is an island with water to the horizon. Positions are worked out in road
-- coordinates (s along the road, d across it; Map/MapGeometry.luau).
--
-- Order matters, each step avoids what the previous ones placed:
--   stations (house/shops/sell pads/signs) -> props -> lawns -> terrain ->
--   road/bridge -> gates and fences -> shore walls -> trees -> sea -> spawn.
-- Everything random comes from one seeded Random, so every server builds
-- the same land.
--
-- Terrain (no ground parts): wild ground is LeafyGrass (short), lawns are
-- Grass (tall blades = "mow me"), beaches are Sand, then Water. GrassService
-- owns the lawn cells after this.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MapLayout = require(Shared.Config.MapLayout)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Format)

local Props = require(script.Parent.Map.Props)
local ShopDisplay = require(script.Parent.Map.ShopDisplay)
local ShopInterior = require(script.Parent.Map.ShopInterior)
local Geo = require(script.Parent.Map.MapGeometry)

local MapService = {}

local CELL = 4 -- Terrain voxel; lawn cells are one voxel column
local GROUND_TOP = Props.GroundTop
local COLORS = Props.Colors
local ROAD = MapLayout.Road
local ROAD_HALF = ROAD.Width / 2
-- Smooth terrain draws a filled voxel's surface 2 studs above its top edge
-- (Props.GroundTop): fill to `surface - SURFACE_LIFT` to get a surface.
local SURFACE_LIFT = 2
local WATER_LEVEL = GROUND_TOP - 2.6
local LAWN_MARGIN = 4 -- studs kept clear around props
local terrain = Workspace.Terrain

MapService.Materials = {
	Wild = Enum.Material.LeafyGrass,
	Lawn = Enum.Material.Grass,
	Beach = Enum.Material.Sand,
	Rock = Enum.Material.Rock,
}

local rng: Random

-- Grid helpers ----------------------------------------------------------------

local function key(x: number, z: number): string
	return math.floor(x / CELL) .. "," .. math.floor(z / CELL)
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

local function ground(point: Vector3): Vector3
	return Vector3.new(point.X, GROUND_TOP, point.Z)
end

-- Frame on the ground at road coordinates (s, d) whose +Z (the prop's
-- front) faces the road; on the road itself it faces along the road.
local function facingRoad(s: number, d: number): CFrame
	local at = ground(Geo.Point(s, d))
	local target = if math.abs(d) < 0.5 then ground(Geo.Point(s + 10, 0)) else ground(Geo.Point(s, 0))
	local away = at - target
	return CFrame.lookAt(at, at + Vector3.new(away.X, 0, away.Z).Unit)
end

-- Paths -----------------------------------------------------------------------

-- A gently curving line from a to b (quadratic Bezier with a sideways bend).
local function curve(a: Vector3, b: Vector3, bend: number): { Vector3 }
	local mid = (a + b) / 2
	local along = b - a
	local side = Vector3.new(-along.Z, 0, along.X).Unit
	local control = mid + side * bend * along.Magnitude
	local points = {}
	local steps = math.max(4, math.ceil(along.Magnitude / 2))
	for i = 0, steps do
		local t = i / steps
		table.insert(points, a:Lerp(control, t):Lerp(control:Lerp(b, t), t))
	end
	return points
end

-- Dirt paths as thin parts (crisp edges; terrain materials blur at this
-- scale). Segments alternate a hair in height so overlaps never z-fight,
-- with round caps at the joints and a few edging stones.
local PATH_COLOR = Color3.fromRGB(196, 168, 120)
local STONE_COLOR = Color3.fromRGB(150, 144, 132)

local function buildPath(folder: Instance, points: { Vector3 }, width: number)
	local index = 0
	for i = 1, #points - 2, 2 do
		local a, b = points[i], points[i + 2]
		local length = (b - a).Magnitude
		if length < 0.5 then
			continue
		end
		index += 1
		local lift = GROUND_TOP + 0.04 + (index % 2) * 0.02
		local mid = (a + b) / 2
		local frame = CFrame.lookAt(Vector3.new(mid.X, lift, mid.Z), Vector3.new(b.X, lift, b.Z))
		Props.make("Path", folder, {
			Size = Vector3.new(width, 0.2, length + 0.4),
			CFrame = frame,
			Color = PATH_COLOR,
			Material = Enum.Material.Ground,
		}).CanQuery = false
		Props.make("PathJoint", folder, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, width, width),
			CFrame = CFrame.new(a.X, GROUND_TOP + 0.05, a.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = PATH_COLOR,
			Material = Enum.Material.Ground,
		}).CanQuery = false
		if rng:NextNumber() < 0.3 and i > 3 and i < #points - 6 then
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local stone = Props.make("EdgeStone", folder, {
				Size = Vector3.new(0.9 + rng:NextNumber() * 0.6, 0.5, 0.8 + rng:NextNumber() * 0.6),
				CFrame = frame * CFrame.new(side * (width / 2 + 0.3), 0.15, 0) * CFrame.Angles(0, rng:NextNumber() * 3, 0),
				Color = STONE_COLOR,
				Material = Enum.Material.Slate,
				Solid = false,
			})
			stone.CastShadow = true
		end
	end
end

-- Shops -------------------------------------------------------------------------

-- "Browse all" prompt on a shop counter: opens the Shop panel client-side.
local function addCounterPrompt(counter: BasePart?)
	if not counter then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenShopPrompt"
	prompt.ObjectText = "Shop"
	prompt.ActionText = "Browse all"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
end

local function buildStall(parent: Instance, cf: CFrame, zone: Zones.ZoneDef, toolIds: { string })
	local stall = Props.shop(parent, cf, 0, 0, zone.ThemeColor)
	addCounterPrompt(stall:FindFirstChild("Counter") :: BasePart?)
	-- Tools hang behind the counter; mowers park in front.
	ShopDisplay.Build(stall, cf * CFrame.new(0, 0, -1.9), toolIds, {
		BoardWidth = 11,
		BoardHeight = 3.6,
		BoardLift = 3.6,
		ParkOffsetX = -9,
		ParkDistance = 9,
	})
end

-- Placement -----------------------------------------------------------------------

type Placed = { Position: Vector3, Radius: number }

local placed: { Placed } = {}
local blocked: { [string]: boolean } = {} -- cells no lawn may cover

local function isClear(point: Vector3, radius: number): boolean
	for _, other in placed do
		if (other.Position - point).Magnitude < other.Radius + radius + 3 then
			return false
		end
	end
	return true
end

local function claim(point: Vector3, radius: number)
	table.insert(placed, { Position = point, Radius = radius })
	markDisc(blocked, point, radius + LAWN_MARGIN)
end

-- A free spot for something of `radius` in an area, beside the road
-- (biased toward it, like a farmyard), as road coordinates; or nil.
local function propSpot(stretch: Geo.Stretch, radius: number): (number?, number?)
	local def = stretch.Def
	for _ = 1, 80 do
		local s = stretch.Start + 24 + rng:NextNumber() * (stretch.Finish - stretch.Start - 40)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local nearest = ROAD_HALF + 5 + radius
		local farthest = Geo.HalfWidth(s, side) - def.Lawns.Rim - radius
		if farthest <= nearest then
			continue
		end
		local d = side * (nearest + (rng:NextNumber() ^ 1.6) * (farthest - nearest))
		local point = Geo.Point(s, d)
		if Geo.FitsIn(point, radius + 2, stretch.Id) and isClear(point, radius) then
			return s, d
		end
	end
	return nil, nil
end

-- Stations: house/shops, sell pads, signs, the quick-travel spot ---------------------

local function stationSpot(stretch: Geo.Stretch, station, radius: number): (number, number)
	local start = if stretch.Index == 1 then 0 else stretch.Start
	return start + station.After, station.Side * (ROAD_HALF + station.Gap + radius)
end

local function buildStations(land: Instance, zoneFolders: { [string]: Folder }, paths: Instance)
	local stations = MapLayout.Stations
	for _, stretch in Geo.Areas do
		local zone = Zones.ById[stretch.Id]
		local toolIds = ShopDisplay.ToolsForZone(Geo.Order[stretch.Id] or 1)

		-- Shop: the house at the road start, or a stall beside the road.
		if stretch.Def.ShopAt == "House" then
			local s = -ShopInterior.Radius - 2
			local cf = facingRoad(s, 0)
			ShopInterior.Build(land, cf, toolIds, "Tool Shop", "Sam · Shopkeeper")
			claim(cf.Position, ShopInterior.Radius)
			-- Footpath from the porch steps onto the road.
			local shop = land:FindFirstChild("ShopBuilding")
			local entrance = shop and shop:GetAttribute("Entrance") :: Vector3?
			if entrance then
				buildPath(paths, curve(entrance, ground(Geo.Point(2, 0)), 0), 6)
			end
		else
			local s, d = stationSpot(stretch, stations.Shop, 7)
			local cf = facingRoad(s, d)
			buildStall(land, cf, zone, toolIds)
			claim(cf.Position, 11)
		end

		-- Sell pad + buyer stall (the pad is the contract part).
		do
			local s, d = stationSpot(stretch, stations.Sell, 5)
			local cf = facingRoad(s, d)
			Props.sellPad(zoneFolders[stretch.Id], cf, 0, 0)
			claim(cf.Position + cf.LookVector * 4, 10)
		end

		-- Room for quick travel later (kept clear of lawns and props).
		do
			local travel = stations.Travel
			local s, d = stationSpot(stretch, travel, travel.Radius)
			claim(Geo.Point(s, d), travel.Radius)
		end

		-- Name sign just before the gate, turned toward whoever walks up the
		-- road from the previous area.
		if stretch.Index > 1 then
			local s, d = stationSpot(stretch, stations.Sign, 2)
			local at = ground(Geo.Point(s, d))
			local viewer = ground(Geo.Point(s - 30, 0))
			local away = at - viewer
			Props.sign(land, CFrame.lookAt(at, at + away.Unit), 0, 0, ("%s\n%s"):format(zone.DisplayName, zone.Subtitle), zone.ThemeColor)
			claim(Geo.Point(s, d), 4)
		end
	end
end

-- Gates and fences ------------------------------------------------------------------

-- One fence line across the land at the start of every area after the
-- first, with the gate on the road. ZoneWall (invisible, above the fence and
-- across the beach) belongs to the area behind it; the player's client
-- drops the walls and opens the gate once that area is unlocked.
local function buildGates(land: Instance, zoneFolders: { [string]: Folder })
	local fences = Props.model("Fences", land)
	local halfGate = MapLayout.GateWidth / 2
	for _, stretch in Geo.Areas do
		if stretch.Index == 1 then
			continue
		end
		local zone = Zones.ById[stretch.Id]
		local folder = zoneFolders[stretch.Id]
		local s = stretch.Start
		local frame = Geo.Frame(s) -- RightVector runs across the road
		local across = frame.RightVector

		for _, side in { 1, -1 } do
			local fenceEnd = Geo.HalfWidth(s, side) - 3
			local wallEnd = Geo.HalfWidth(s, side) + MapLayout.Beach + 6
			local d = halfGate + 0.5
			local last: Vector3? = nil
			while d <= fenceEnd do
				local p = ground(frame.Position + across * (d * side))
				Props.make("Post", fences, {
					Size = Vector3.new(0.9, 4.2, 0.9),
					CFrame = CFrame.new(p + Vector3.new(0, 2.1, 0)),
					Color = COLORS.Fence,
					Material = Enum.Material.Wood,
				})
				if last then
					local mid = (last + p) / 2
					local railFrame = CFrame.lookAt(mid, p)
					for _, height in { 1.5, 3.2 } do
						Props.make("Rail", fences, {
							Size = Vector3.new(0.3, 0.5, (p - last).Magnitude),
							CFrame = railFrame + Vector3.new(0, height, 0),
							Color = COLORS.Fence,
							Material = Enum.Material.Wood,
						})
					end
				end
				last = p
				d += MapLayout.FencePostSpacing
			end
			-- Invisible wall from the gate post to past the waterline.
			local length = wallEnd - halfGate
			local center = frame.Position + across * (side * (halfGate + length / 2))
			local wall = Props.make("ZoneWall", folder, {
				Size = Vector3.new(length, MapLayout.WallHeight + 10, 0.6),
				CFrame = CFrame.lookAt(center, center + frame.LookVector) + Vector3.new(0, GROUND_TOP + MapLayout.WallHeight / 2 - 5, 0),
				Color = COLORS.Fence,
				Transparency = 1,
			})
			wall.CastShadow = false
			wall.CanQuery = false
			wall:SetAttribute("ZoneId", stretch.Id)
		end

		-- Gate posts and the gate itself (contract part, solid until unlocked).
		for _, side in { 1, -1 } do
			local p = ground(frame.Position + across * (side * (halfGate + 0.4)))
			Props.make("GatePost", fences, {
				Size = Vector3.new(1.4, 7, 1.4),
				CFrame = CFrame.new(p + Vector3.new(0, 3.5, 0)),
				Color = COLORS.DarkWood,
				Material = Enum.Material.Wood,
			})
		end
		local gate = Props.make("ZoneGate", folder, {
			Size = Vector3.new(MapLayout.GateWidth, MapLayout.WallHeight, 0.6),
			CFrame = frame + Vector3.new(0, GROUND_TOP + MapLayout.WallHeight / 2, 0),
			Color = zone.ThemeColor,
			Material = Enum.Material.Glass,
			Transparency = 0.35,
		})
		local text = ("LOCKED\n%s\n%s · Lv %d"):format(zone.DisplayName, Format.Coins(zone.UnlockPrice), zone.RequiredLevel)
		Props.label(gate, Enum.NormalId.Front, text, Color3.new(1, 1, 1))
		Props.label(gate, Enum.NormalId.Back, text, Color3.new(1, 1, 1))
	end
end

-- Shore walls: invisible walls along the waterline (grid edges between
-- cells inside the line and cells past it, merged into long runs).
local function buildShoreWalls(land: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "PerimeterWalls"
	local limit = MapLayout.Beach - 6
	local inside: { [string]: boolean } = {}
	Geo.ForEachCell(function(ix, iz, _center, s, d)
		if Geo.EdgeDistance(s, d) < limit then
			inside[ix .. "," .. iz] = true
		end
	end)
	-- Edges keyed by the line they lie on, then merged.
	local xEdges: { [number]: { number } } = {} -- x line -> list of iz
	local zEdges: { [number]: { number } } = {} -- z line -> list of ix
	for k in inside do
		local ix, iz = string.match(k, "^(-?%d+),(-?%d+)$")
		local x, z = tonumber(ix) :: number, tonumber(iz) :: number
		if not inside[(x + 1) .. "," .. z] then
			xEdges[x + 1] = xEdges[x + 1] or {}
			table.insert(xEdges[x + 1], z)
		end
		if not inside[(x - 1) .. "," .. z] then
			xEdges[x] = xEdges[x] or {}
			table.insert(xEdges[x], z)
		end
		if not inside[x .. "," .. (z + 1)] then
			zEdges[z + 1] = zEdges[z + 1] or {}
			table.insert(zEdges[z + 1], x)
		end
		if not inside[x .. "," .. (z - 1)] then
			zEdges[z] = zEdges[z] or {}
			table.insert(zEdges[z], x)
		end
	end
	local height = MapLayout.ShoreWallHeight
	local bottom = -MapLayout.WaterDepth
	local function runs(lines: { [number]: { number } }, alongX: boolean)
		for line, list in lines do
			table.sort(list)
			local first = 1
			for i = 1, #list do
				if list[i + 1] ~= list[i] + 1 then
					local a, b = list[first], list[i] + 1
					local length = (b - a) * CELL
					local mid = (a + b) / 2 * CELL
					local size = if alongX then Vector3.new(length, height, 1) else Vector3.new(1, height, length)
					local pos = if alongX then Vector3.new(mid, bottom + height / 2, line * CELL) else Vector3.new(line * CELL, bottom + height / 2, mid)
					local wall = Props.make("ShoreWall", folder, {
						Size = size,
						CFrame = CFrame.new(pos),
						Color = COLORS.Water,
						Transparency = 1,
					})
					wall.CastShadow = false
					wall.CanQuery = false
					first = i + 1
				end
			end
		end
	end
	runs(xEdges, false)
	runs(zEdges, true)
	folder.Parent = land
end

-- Terrain -------------------------------------------------------------------------------

-- Surface height of a cell: flat land, a beach sloping into the water.
local function surfaceAt(edge: number): number
	if edge < 0 then
		return GROUND_TOP
	end
	local t = math.clamp(edge / MapLayout.Beach, 0, 1)
	return GROUND_TOP - 0.4 - t * (GROUND_TOP - WATER_LEVEL + 4)
end

local function fillColumn(center: Vector3, top: number, material: Enum.Material)
	local bottom = -MapLayout.WaterDepth - 4
	local height = top - SURFACE_LIFT - bottom
	if height > 0 then
		terrain:FillBlock(CFrame.new(center.X, bottom + height / 2, center.Z), Vector3.new(CELL, height, CELL), material)
	end
end

-- Sea to the horizon: water over a sand floor, in tiles.
local function fillSea(minX: number, maxX: number, minZ: number, maxZ: number)
	local tile = 512
	local waterTop = WATER_LEVEL - SURFACE_LIFT
	local floorTop = -MapLayout.WaterDepth
	for x = minX, maxX, tile do
		for z = minZ, maxZ, tile do
			local w, l = math.min(tile, maxX - x), math.min(tile, maxZ - z)
			local cx, cz = x + w / 2, z + l / 2
			terrain:FillBlock(CFrame.new(cx, floorTop - 4, cz), Vector3.new(w, 8, l), MapService.Materials.Beach)
			terrain:FillBlock(CFrame.new(cx, (floorTop + waterTop) / 2, cz), Vector3.new(w, waterTop - floorTop, l), Enum.Material.Water)
			task.wait()
		end
	end
end

-- Past the terrain sea: flat water-colored plates out to `FarSea` studs.
-- Clients only draw terrain up to a limited distance, so without them the
-- sea would end in a jagged edge; the plates carry it into the haze. They
-- start under the outer terrain water (overlap, no gap) and sit just under
-- its surface, far from where anyone swims.
local function buildFarSea(parent: Instance, minX: number, maxX: number, minZ: number, maxZ: number)
	local folder = Instance.new("Folder")
	folder.Name = "FarSea"
	local tile = 2048 -- largest part size
	local function plates(x1: number, x2: number, z1: number, z2: number)
		for x = x1, x2 - 1, tile do
			for z = z1, z2 - 1, tile do
				local xe, ze = math.min(x + tile, x2), math.min(z + tile, z2)
				local plate = Props.make("SeaPlate", folder, {
					Size = Vector3.new(xe - x, 1, ze - z),
					CFrame = CFrame.new((x + xe) / 2, WATER_LEVEL - 0.8, (z + ze) / 2),
					Color = MapLayout.FarSeaColor,
					Material = Enum.Material.SmoothPlastic,
					Solid = false,
				})
			end
		end
	end
	-- A ring: west and east strips, then north and south between them.
	local reach = MapLayout.FarSea
	plates(minX - reach, minX, minZ - reach, maxZ + reach)
	plates(maxX, maxX + reach, minZ - reach, maxZ + reach)
	plates(minX, maxX, minZ - reach, minZ)
	plates(minX, maxX, maxZ, maxZ + reach)
	folder.Parent = parent
end

-- A wooded hill rising out of the water (islets, the far coast).
local function island(forest: Instance, center: Vector3, radius: number, trees: number)
	terrain:FillBall(Vector3.new(center.X, WATER_LEVEL - radius * 0.62, center.Z), radius, MapService.Materials.Wild)
	local top = WATER_LEVEL + radius * 0.38
	for _ = 1, trees do
		local a = rng:NextNumber() * math.pi * 2
		local r = math.sqrt(rng:NextNumber()) * radius * 0.6
		local x, z = center.X + math.cos(a) * r, center.Z + math.sin(a) * r
		-- Height of the ball's surface at that distance.
		local y = WATER_LEVEL - radius * 0.62 + math.sqrt(math.max(radius * radius - r * r, 0)) + 0.5
		if y > WATER_LEVEL + 1 and y <= top + 1 then
			Props.tree(forest, CFrame.new(x, y, z), 0, 0, 1 + rng:NextNumber() * 1.2)
		end
	end
end

-- Build ---------------------------------------------------------------------------

local function buildSpawn()
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "GameSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.4, 6)
	local at = Geo.Point(8, 0)
	spawn.CFrame = CFrame.lookAt(ground(at), ground(Geo.Point(20, 0))) + Vector3.new(0, 0.2, 0)
	-- Invisible and walk-through: players just appear on the road.
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CastShadow = false
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

	-- Terrain and water colors (saved with a baked map; tune them in Studio
	-- under Terrain > MaterialColors and they stay).
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(76, 124, 56)) -- wild ground
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(92, 168, 60)) -- uncut lawn
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(150, 204, 92)) -- mowed stripe
	terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(116, 178, 70)) -- mowed stripe
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(226, 206, 156)) -- beach
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(132, 126, 118)) -- shore rocks
	terrain.WaterColor = Color3.fromRGB(56, 142, 168)
	terrain.WaterTransparency = 0.45
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8

	rng = Random.new(MapLayout.Seed)
	table.clear(placed)
	table.clear(blocked)
	local land = Props.model("Land", Workspace)
	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	local zoneFolders: { [string]: Folder } = {}
	for _, zone in Zones.List do
		local folder = Instance.new("Folder")
		folder.Name = zone.Id
		folder.Parent = zonesFolder
		zoneFolders[zone.Id] = folder
		if not MapLayout.Areas[zone.Id] then
			warn(("[MowIt][Map] No MapLayout row for zone %q."):format(zone.Id))
		end
	end
	local paths = Props.model("Paths", land)

	-- 1. Stations next to the road, then each area's props.
	buildStations(land, zoneFolders, paths)
	local dressing = Props.model("Dressing", land)
	for _, stretch in Geo.Areas do
		for _, name in stretch.Def.Props do
			local kind = Props.Kinds[name]
			if not kind then
				warn(("[MowIt][Map] Unknown prop %q in MapLayout (zone %s)."):format(name, stretch.Id))
				continue
			end
			local s, d = propSpot(stretch, kind.Radius)
			if s and d then
				local cf = facingRoad(s, d)
				claim(cf.Position, kind.Radius)
				kind.Build(dressing, cf)
				-- A short farm track from the road to it.
				local from = ground(Geo.Point(s, math.sign(d) * (ROAD_HALF - 1)))
				local to = cf.Position + cf.LookVector * -(kind.Radius * 0.6)
				local track = curve(from, Vector3.new(to.X, GROUND_TOP, to.Z), 0.08)
				buildPath(paths, track, 5)
				for _, point in track do
					markDisc(blocked, point, 4)
				end
			else
				warn(("[MowIt][Map] No room for %s in %s."):format(name, stretch.Id))
			end
		end
		-- Small clearings in the fields (wild ground, maybe a tree).
		for _ = 1, stretch.Def.Lawns.Holes do
			local s, d = propSpot(stretch, 6)
			if s and d then
				local point = Geo.Point(s, d)
				claim(point, 3 + rng:NextNumber() * 4)
				if rng:NextNumber() < 0.6 then
					Props.tree(dressing, CFrame.new(ground(point)), 0, 0, 0.9 + rng:NextNumber() * 0.5)
				end
			end
		end
	end

	-- 2. Lawns: everything between the road verge and the tree line, minus
	-- what step 1 claimed. Edges wobble so the fields look organic.
	local lawnCells: { [string]: { { Ix: number, Iz: number } } } = {}
	local lawnSet: { [string]: boolean } = {}
	local count = 0
	Geo.ForEachCell(function(ix, iz, center, s, d)
		if Geo.EdgeDistance(s, d) >= 0 or blocked[ix .. "," .. iz] then
			return
		end
		local stretch = Geo.StretchAt(s) :: Geo.Stretch
		local lawns = stretch.Def.Lawns
		local side = if d >= 0 then 1 else -1
		local inner = ROAD_HALF + lawns.Verge + 1.5 + Geo.Wobble(s, side * 1.3 + stretch.Index, 1.5)
		local outer = Geo.HalfWidth(s, side) - lawns.Rim - 3 - Geo.Wobble(s, side * 2.9 + stretch.Index, 3)
		local start = if stretch.Index == 1 then 4 else stretch.Start + 6
		local margin = 6 + Geo.Wobble(d, stretch.Index * 1.7, 3)
		if math.abs(d) < inner or math.abs(d) > outer or s < start + margin or s > stretch.Finish - margin then
			return
		end
		if Geo.AreaAt(center) ~= stretch.Id then
			return
		end
		lawnCells[stretch.Id] = lawnCells[stretch.Id] or {}
		table.insert(lawnCells[stretch.Id], { Ix = ix, Iz = iz })
		lawnSet[ix .. "," .. iz] = true
		count += 1
	end)

	-- 3. Terrain: the sea, then every land/beach column, then lawns painted in.
	do
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		Geo.ForEachCell(function(_ix, _iz, center)
			minX, maxX = math.min(minX, center.X), math.max(maxX, center.X)
			minZ, maxZ = math.min(minZ, center.Z), math.max(maxZ, center.Z)
		end)
		local far = Geo.Point(Geo.RoadEnd + MapLayout.FarLandDistance, 0)
		minX, maxX = math.min(minX, far.X), math.max(maxX, far.X)
		minZ, maxZ = math.min(minZ, far.Z), math.max(maxZ, far.Z)
		local margin = MapLayout.SeaMargin
		fillSea(minX - margin, maxX + margin, minZ - margin, maxZ + margin)
		local inner = margin - MapLayout.FarSeaOverlap
		buildFarSea(land, minX - inner, maxX + inner, minZ - inner, maxZ + inner)
	end
	local filled = 0
	Geo.ForEachCell(function(_ix, _iz, center, s, d)
		local edge = Geo.EdgeDistance(s, d)
		if edge < MapLayout.Beach then
			fillColumn(center, surfaceAt(edge), if edge < 0 then MapService.Materials.Wild else MapService.Materials.Beach)
			filled += 1
			if filled % 600 == 0 then
				task.wait()
			end
		end
	end)
	for _, cells in lawnCells do
		for _, c in cells do
			local center = Vector3.new(c.Ix * CELL + CELL / 2, GROUND_TOP, c.Iz * CELL + CELL / 2)
			terrain:ReplaceMaterial(columnRegion(center), CELL, MapService.Materials.Wild, MapService.Materials.Lawn)
		end
		task.wait()
	end

	-- 4. The road, from the house to the shore, and a closed bridge beyond.
	buildPath(paths, Geo.RoadPoints(0, Geo.LandEnd + 2, 4), ROAD.Width)
	do
		local bridge = Props.model("Bridge", land)
		local deckY = GROUND_TOP + 0.6
		local s = Geo.LandEnd + 2
		while s < Geo.RoadEnd do
			local a, b = Geo.Point(s, 0), Geo.Point(math.min(s + 8, Geo.RoadEnd), 0)
			local mid = (a + b) / 2
			local frame = CFrame.lookAt(Vector3.new(mid.X, deckY, mid.Z), Vector3.new(b.X, deckY, b.Z))
			Props.make("Deck", bridge, {
				Size = Vector3.new(ROAD.Width - 2, 0.8, (b - a).Magnitude + 0.2),
				CFrame = frame,
				Color = COLORS.Wood,
				Material = Enum.Material.WoodPlanks,
			})
			for _, side in { -1, 1 } do
				Props.make("Rail", bridge, {
					Size = Vector3.new(0.4, 0.5, (b - a).Magnitude + 0.2),
					CFrame = frame * CFrame.new(side * (ROAD_HALF - 1.2), 2.6, 0),
					Color = COLORS.DarkWood,
					Material = Enum.Material.Wood,
				})
				Props.make("Pile", bridge, {
					Size = Vector3.new(0.9, MapLayout.WaterDepth + 6, 0.9),
					CFrame = CFrame.new((frame * CFrame.new(side * (ROAD_HALF - 1.2), 0, -4)).Position - Vector3.new(0, (MapLayout.WaterDepth + 6) / 2 - 3, 0)),
					Color = COLORS.DarkWood,
					Material = Enum.Material.Wood,
				})
			end
			s += 8
		end
		-- Closed for now: the road goes on, the land is not for sale yet.
		local barrier = facingRoad(Geo.LandEnd + 6, 0) * CFrame.Angles(0, math.pi, 0)
		for _, x in { -ROAD_HALF + 1.5, ROAD_HALF - 1.5 } do
			Props.box("BarrierPost", bridge, barrier, Vector3.new(0.6, 4, 0.6), x, 0, COLORS.DarkWood, Enum.Material.Wood)
		end
		for i, y in { 1.6, 3 } do
			Props.box("BarrierBoard", bridge, barrier, Vector3.new(ROAD.Width - 2, 0.7, 0.3), 0, 0, if i == 1 then COLORS.BarnRed else COLORS.White, nil, y)
		end
		Props.sign(bridge, barrier * CFrame.new(0, 0, -2), 0, 0, "ROAD CLOSED\nMore land coming soon", COLORS.BarnRed)
		island(bridge, ground(Geo.Point(Geo.RoadEnd + 34, 0)), 40, 9)
		-- The far coast, in the haze past the bridge.
		local forward = Geo.Frame(Geo.RoadEnd)
		for i = -4, 4 do
			local p = (forward * CFrame.new(i * 150 + rng:NextNumber() * 60, 0, -MapLayout.FarLandDistance - math.abs(i) * 40 - rng:NextNumber() * 80)).Position
			island(bridge, ground(p), 70 + rng:NextNumber() * 50, 14)
		end
	end

	-- 5. Gates and fence lines, then the shore walls.
	buildGates(land, zoneFolders)
	buildShoreWalls(land)

	-- 6. Trees: a tree line along each area's sides (in clusters), never on
	-- lawns, the road or anything claimed; some behind the house.
	local trees = Props.model("Trees", land)
	local function tryTree(point: Vector3, scale: number): boolean
		local k = key(point.X, point.Z)
		local s, d = Geo.Locate(point)
		if not s or lawnSet[k] or blocked[k] or math.abs(d :: number) < ROAD_HALF + 3 or not isClear(point, 3) then
			return false
		end
		if Geo.EdgeDistance(s, d :: number) > MapLayout.Beach * 0.25 then
			return false
		end
		table.insert(placed, { Position = point, Radius = 2.5 })
		Props.tree(trees, CFrame.new(ground(point)), 0, 0, scale)
		return true
	end
	for _, stretch in Geo.Areas do
		local def = stretch.Def
		for _ = 1, def.Trees do
			local s = stretch.Start + rng:NextNumber() * (stretch.Finish - stretch.Start)
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local d = side * (Geo.HalfWidth(s, side) - def.Lawns.Rim * rng:NextNumber() + 2)
			local point = Geo.Point(s, d)
			if tryTree(point, 1 + rng:NextNumber() * 0.7) then
				for _ = 1, rng:NextInteger(0, 2) do
					local a = rng:NextNumber() * math.pi * 2
					tryTree(point + Vector3.new(math.cos(a), 0, math.sin(a)) * (5 + rng:NextNumber() * 4), 0.8 + rng:NextNumber() * 0.6)
				end
			end
		end
	end
	for _ = 1, 22 do
		local s = Geo.LandStart + rng:NextNumber() * (Geo.LandStart * -1 - 4)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		tryTree(Geo.Point(s, side * (ROAD_HALF + 4 + rng:NextNumber() * Geo.HalfWidth(s, side))), 1 + rng:NextNumber() * 0.6)
	end

	-- 7. Shore rocks on the beaches and wooded islets out in the water.
	for _ = 1, MapLayout.ShoreRocks do
		local s = Geo.LandStart + rng:NextNumber() * (Geo.LandEnd - Geo.LandStart)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local d = side * (Geo.HalfWidth(s, side) + MapLayout.Beach * (0.35 + rng:NextNumber() * 0.5))
		local p = Geo.Point(s, d)
		terrain:FillBall(Vector3.new(p.X, WATER_LEVEL - 1, p.Z), 3 + rng:NextNumber() * 5, MapService.Materials.Rock)
	end
	for _ = 1, MapLayout.Islets do
		local s = Geo.LandStart + rng:NextNumber() * (Geo.LandEnd - Geo.LandStart)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local d = side * (Geo.HalfWidth(s, side) + MapLayout.Beach + 100 + rng:NextNumber() * 380)
		island(trees, ground(Geo.Point(s, d)), 22 + rng:NextNumber() * 34, 6)
	end

	-- 8. Lawns as contract parts: invisible "GrassArea" strips (one per run
	-- of cells in a row). GrassService grows grass wherever these are, so a
	-- baked map can be re-shaped in Studio by moving/resizing them.
	for zoneId, cells in lawnCells do
		local rows: { [number]: { number } } = {}
		for _, c in cells do
			rows[c.Iz] = rows[c.Iz] or {}
			table.insert(rows[c.Iz], c.Ix)
		end
		local lawns = Instance.new("Folder")
		lawns.Name = "Lawns"
		for iz, xs in rows do
			table.sort(xs)
			local runStart = xs[1]
			for i = 1, #xs do
				local x = xs[i]
				if xs[i + 1] ~= x + 1 then
					local run = x - runStart + 1
					local part = Props.make("GrassArea", lawns, {
						Size = Vector3.new(run * CELL, 0.2, CELL),
						CFrame = CFrame.new((runStart + run / 2) * CELL, GROUND_TOP + 0.1, iz * CELL + CELL / 2),
						Color = Color3.fromRGB(92, 168, 60),
						Transparency = 1,
						Solid = false,
					})
					part.Locked = false
					runStart = xs[i + 1]
				end
			end
		end
		lawns.Parent = zoneFolders[zoneId]
	end

	zonesFolder.Parent = Workspace
	buildSpawn()
	print(("[MowIt][Map] Land built: %d lawn cells, %d areas, road %d studs."):format(count, #Geo.Areas, math.floor(Geo.LandEnd)))
end

-- Edit-mode "bake": run from the Command Bar (or Studio MCP) to build the
-- land into the place so it can be edited by hand and saved:
--   require(game.ServerScriptService.Services.MapService).Bake()
-- Does nothing if Workspace/Zones already exists. See docs/EDITING.md.
function MapService.Bake()
	MapService.BuildIfMissing()
end

return MapService
