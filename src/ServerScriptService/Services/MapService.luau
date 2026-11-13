--!strict
-- Builds the land from Shared/Config/MapLayout.luau when the place has no
-- Workspace/Zones yet (a baked or hand-built map replaces it; the contract
-- names stay the same: Zones/<id>/ZoneGate, ZoneWall, SellPad, GrassArea).
--
-- The land is a chain of islands (see MapLayout.luau and Map/MapGeometry):
-- one island per area, a wooden bridge from each island to the next with
-- that area's gate in the middle, big lawns over most of every island, a
-- dirt path from bridge to bridge, sell pad and shop where each bridge
-- arrives, trees and cliffs along the coasts, islets and rocks in the sea,
-- and water to the horizon.
--
-- Order matters, each step avoids what the previous ones placed:
--   paths + stations -> props -> lawns -> terrain -> bridges/gates ->
--   shore walls -> trees -> sea dressing -> spawn.
-- Everything random comes from one seeded Random, so every server builds
-- the same land.
--
-- Terrain (no ground parts): wild ground LeafyGrass, lawns Grass (tall
-- blades = "mow me"), beaches Sand, cliffs Rock, then Water. GrassService
-- owns the lawn cells after this.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MapLayout = require(Shared.Config.MapLayout)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Format)
local Quests = require(Shared.Config.Quests)

local Props = require(script.Parent.Map.Props)
local ShopDisplay = require(script.Parent.Map.ShopDisplay)
local ShopInterior = require(script.Parent.Map.ShopInterior)
local FarmerStand = require(script.Parent.Map.FarmerStand)
local Geo = require(script.Parent.Map.MapGeometry)

local MapService = {}

local CELL = 4 -- Terrain voxel; lawn cells are one voxel column
local GROUND_TOP = Props.GroundTop
local COLORS = Props.Colors
local BEACH = MapLayout.Beach
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

-- Helpers ---------------------------------------------------------------------

local function key(x: number, z: number): string
	return math.floor(x / CELL) .. "," .. math.floor(z / CELL)
end

local function flatY(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
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

local function ground(point: Vector3, lift: number?): Vector3
	return Vector3.new(point.X, GROUND_TOP + (lift or 0), point.Z)
end

-- A ground frame at `point` whose +Z (a prop's front) faces `target`.
local function facing(point: Vector3, target: Vector3): CFrame
	local at = ground(point)
	local away = at - ground(target)
	if away.Magnitude < 0.1 then
		away = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(at, at + away.Unit)
end

-- A smooth curve through the given points (Catmull-Rom), every ~2 studs.
local function spline(points: { Vector3 }): { Vector3 }
	local out = {}
	for i = 1, #points - 1 do
		local p0, p1 = points[math.max(i - 1, 1)], points[i]
		local p2, p3 = points[i + 1], points[math.min(i + 2, #points)]
		local steps = math.max(2, math.ceil((p2 - p1).Magnitude / 2))
		for k = 0, steps - 1 do
			local t = k / steps
			local t2, t3 = t * t, t * t * t
			table.insert(out, 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
		end
	end
	table.insert(out, points[#points])
	return out
end

-- Dirt paths as thin parts (crisp edges; terrain materials blur at this
-- scale). Segments alternate a hair in height so overlaps never z-fight,
-- with round caps at the joints and a few edging stones.
local PATH_COLOR = Color3.fromRGB(214, 176, 122)
local STONE_COLOR = Color3.fromRGB(160, 150, 136)

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

-- Placement -----------------------------------------------------------------------

type Placed = { Position: Vector3, Radius: number }

local placed: { Placed } = {}
local blocked: { [string]: boolean } = {} -- cells no lawn may cover

local function isClear(point: Vector3, radius: number): boolean
	for _, other in placed do
		if (other.Position - flatY(point)).Magnitude < other.Radius + radius + 3 then
			return false
		end
	end
	return not blocked[key(point.X, point.Z)]
end

local function claim(point: Vector3, radius: number)
	table.insert(placed, { Position = flatY(point), Radius = radius })
	markDisc(blocked, point, radius + LAWN_MARGIN)
end

-- A free spot on an island for something of `radius`, or nil.
local function propSpot(island: Geo.Island, radius: number, margin: number): Vector3?
	for _ = 1, 80 do
		local point = Geo.RandomPointOn(island, margin + radius, rng)
		if point and isClear(point, radius) then
			return point
		end
	end
	return nil
end

-- Terrain -------------------------------------------------------------------------------

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- 0..1: how much the coast at this angle is cliff (never at bridges/piers).
local function cliffAt(island: Geo.Island, angle: number, keepClear: { number }): number
	local c = smooth((Geo.CoastNoise(island, angle, 1.7) - (1 - island.Def.Cliffs)) / 0.12)
	for _, clear in keepClear do
		local diff = math.abs(((angle - clear) + 180) % 360 - 180)
		c *= smooth((diff - 14) / 16)
	end
	return c
end

-- Surface height and material for a cell `edge` studs from a coast
-- (negative inland). Flat lawns inland, a rise and rock cliffs at some
-- coasts, sand beaches elsewhere, then the sea floor sloping away.
local function surfaceAt(edge: number, cliff: number): (number, Enum.Material)
	local cliffTop = GROUND_TOP + MapLayout.CliffHeight * cliff
	if edge < -BEACH - 3 then
		return GROUND_TOP, MapService.Materials.Wild
	elseif edge < -BEACH then
		local t = smooth((edge + BEACH + 3) / 3)
		return GROUND_TOP + (cliffTop - GROUND_TOP) * t, MapService.Materials.Wild
	elseif edge < 0 then
		local t = (edge + BEACH) / BEACH
		local beachY = GROUND_TOP - 0.2 - t * (GROUND_TOP - WATER_LEVEL + 1.6)
		local cliffY = if edge < -3 then cliffTop else WATER_LEVEL - 2
		local y = beachY + (cliffY - beachY) * cliff
		local material = MapService.Materials.Beach
		if cliff > 0.45 then
			material = if edge < -BEACH + 4 then MapService.Materials.Wild else MapService.Materials.Rock
		end
		return y, material
	end
	local y = math.max(WATER_LEVEL - 1.8 - edge * 0.45, -MapLayout.WaterDepth + 2)
	return y, if cliff > 0.45 then MapService.Materials.Rock else MapService.Materials.Beach
end

local function fillColumn(center: Vector3, top: number, material: Enum.Material)
	local bottom = -MapLayout.WaterDepth - 6
	local height = top - SURFACE_LIFT - bottom
	if height > 0 then
		terrain:FillBlock(CFrame.new(center.X, bottom + height / 2, center.Z), Vector3.new(CELL, height, CELL), material)
	end
end

-- Water over a sand floor, in tiles.
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
-- sea would end in a jagged edge; the plates carry it to the horizon. They
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
				Props.make("SeaPlate", folder, {
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

-- A small wooded islet: a grassy hill on a sand foot.
local function islet(parent: Instance, center: Vector3, radius: number, trees: number)
	terrain:FillBall(Vector3.new(center.X, WATER_LEVEL - radius * 0.9, center.Z), radius * 1.15, MapService.Materials.Beach)
	terrain:FillBall(Vector3.new(center.X, WATER_LEVEL - radius * 0.5, center.Z), radius * 0.85, MapService.Materials.Wild)
	for _ = 1, trees do
		local a = rng:NextNumber() * math.pi * 2
		local r = math.sqrt(rng:NextNumber()) * radius * 0.4
		local x, z = center.X + math.cos(a) * r, center.Z + math.sin(a) * r
		local rr = radius * 0.85
		local y = WATER_LEVEL - radius * 0.5 + math.sqrt(math.max(rr * rr - r * r, 0)) - 0.3
		if y > WATER_LEVEL + 1 then
			Props.place("Tree", parent, CFrame.new(x, y, z) * CFrame.Angles(0, rng:NextNumber() * 6.28, 0), 0.8 + rng:NextNumber() * 0.6)
		end
	end
end

-- Bridges and gates -------------------------------------------------------------------

local function bridgeDeckY(t: number): number
	-- A gentle arch: ends on the beaches, 2.5 studs higher in the middle.
	return GROUND_TOP + 0.4 + math.sin(math.pi * math.clamp(t, 0, 1)) * 2.5
end

-- A wooden bridge from `a` to `b` (points at y = 0): deck, rails, posts, piles.
local function buildBridgeDeck(folder: Instance, a: Vector3, b: Vector3)
	local width = MapLayout.Bridge.Width
	local dir = (b - a).Unit
	local length = (b - a).Magnitude
	local count = math.max(2, math.ceil(length / 4))
	for i = 0, count - 1 do
		local t0, t1 = i / count, (i + 1) / count
		local p0 = a + dir * length * t0 + Vector3.new(0, bridgeDeckY(t0), 0)
		local p1 = a + dir * length * t1 + Vector3.new(0, bridgeDeckY(t1), 0)
		local frame = CFrame.lookAt((p0 + p1) / 2, p1)
		local span = (p1 - p0).Magnitude
		Props.make("Deck", folder, {
			Size = Vector3.new(width, 0.6, span + 0.15),
			CFrame = frame,
			Color = if i % 2 == 0 then COLORS.Wood else COLORS.Wood:Lerp(COLORS.DarkWood, 0.18),
			Material = Enum.Material.WoodPlanks,
		})
		for _, side in { -1, 1 } do
			Props.make("Rail", folder, {
				Size = Vector3.new(0.5, 0.4, span + 0.15),
				CFrame = frame * CFrame.new(side * (width / 2 - 0.25), MapLayout.Bridge.RailHeight, 0),
				Color = COLORS.DarkWood,
				Material = Enum.Material.Wood,
			})
			Props.make("Post", folder, {
				Size = Vector3.new(0.7, MapLayout.Bridge.RailHeight + 0.4, 0.7),
				CFrame = CFrame.new((frame * CFrame.new(side * (width / 2 - 0.25), MapLayout.Bridge.RailHeight / 2, span / 2)).Position),
				Color = COLORS.DarkWood,
				Material = Enum.Material.Wood,
			})
			if i % 3 == 1 then
				local top = (frame * CFrame.new(side * (width / 2 - 0.6), -0.3, 0)).Position
				local bottom = -MapLayout.WaterDepth
				Props.make("Pile", folder, {
					Size = Vector3.new(1.1, top.Y - bottom, 1.1),
					CFrame = CFrame.new(top.X, (top.Y + bottom) / 2, top.Z),
					Color = COLORS.DarkWood,
					Material = Enum.Material.Wood,
				})
			end
		end
	end
end

-- Every bridge: deck from beach to beach, invisible side walls (no jumping
-- into the water), and the area's gate in the middle (contract ZoneGate;
-- ZoneWall above it so nobody jumps over).
local function buildBridges(land: Instance, zoneFolders: { [string]: Folder }, walls: Folder)
	local folder = Props.model("Bridges", land)
	for _, island in Geo.Islands do
		local bridge = Geo.BridgeTo(island)
		if not bridge then
			continue
		end
		local zone = Zones.ById[island.Id]
		local a = bridge.Start - bridge.Direction * (BEACH - 2)
		local b = bridge.Finish + bridge.Direction * (BEACH - 2)
		buildBridgeDeck(folder, a, b)

		-- Corridor walls along both sides, from coast to coast and a bit inland.
		local wa = bridge.Start - bridge.Direction * 6
		local wb = bridge.Finish + bridge.Direction * 6
		local mid = (wa + wb) / 2
		local along = CFrame.lookAt(mid, mid + bridge.Direction)
		local height = MapLayout.ShoreWallHeight + MapLayout.WaterDepth
		for _, side in { -1, 1 } do
			local wall = Props.make("BridgeWall", walls, {
				Size = Vector3.new(3, height, (wb - wa).Magnitude),
				CFrame = along * CFrame.new(side * (MapLayout.Bridge.Width / 2 + 1.5), -MapLayout.WaterDepth + height / 2, 0),
				Color = COLORS.Water,
				Transparency = 1,
			})
			wall.CastShadow = false
			wall.CanQuery = false
		end

		-- The gate in the middle of the bridge, under an arch with the name.
		local deckTop = bridge.Gate + Vector3.new(0, bridgeDeckY(0.5) + 0.3, 0)
		local gateFrame = CFrame.lookAt(deckTop, deckTop + bridge.Direction)
		local gate = Props.make("ZoneGate", zoneFolders[island.Id], {
			Size = Vector3.new(MapLayout.GateWidth, MapLayout.WallHeight, 0.6),
			CFrame = gateFrame * CFrame.new(0, MapLayout.WallHeight / 2, 0),
			Color = zone.ThemeColor,
			Material = Enum.Material.Glass,
			Transparency = 0.35,
		})
		local text = ("LOCKED\n%s\n%s · Lv %d"):format(zone.DisplayName, Format.Coins(zone.UnlockPrice), zone.RequiredLevel)
		Props.label(gate, Enum.NormalId.Front, text, Color3.new(1, 1, 1))
		Props.label(gate, Enum.NormalId.Back, text, Color3.new(1, 1, 1))
		local above = Props.make("ZoneWall", zoneFolders[island.Id], {
			Size = Vector3.new(MapLayout.GateWidth + 2, MapLayout.ShoreWallHeight, 0.6),
			CFrame = gateFrame * CFrame.new(0, MapLayout.WallHeight + MapLayout.ShoreWallHeight / 2, 0),
			Color = zone.ThemeColor,
			Transparency = 1,
		})
		above.CastShadow = false
		above.CanQuery = false
		above:SetAttribute("ZoneId", island.Id)
		Props.gateArch(folder, gateFrame, MapLayout.Bridge.Width, MapLayout.WallHeight, zone.DisplayName, zone.ThemeColor)
	end
end

-- Invisible walls just offshore around every island, open where bridges
-- (and the last island's pier) leave the coast.
local function buildShoreWalls(walls: Folder, openings: { { Point: Vector3, Direction: Vector3 } })
	local height = MapLayout.ShoreWallHeight + MapLayout.WaterDepth
	local halfLane = MapLayout.Bridge.Width / 2 + 1
	for _, island in Geo.Islands do
		local count = math.ceil(2 * math.pi * island.Def.Radius * 1.25 / 4)
		local points = {}
		for i = 0, count do
			local angle = i * 360 / count
			local r = Geo.CoastRadius(island, angle) + MapLayout.ShoreWallOffset
			table.insert(points, island.Center + Geo.Direction(angle) * r)
		end
		for i = 1, count do
			local p, q = points[i], points[i + 1]
			local mid = (p + q) / 2
			local open = false
			for _, opening in openings do
				local rel = mid - opening.Point
				local along = rel:Dot(opening.Direction)
				local across = math.abs(rel:Dot(opening.Direction:Cross(Vector3.yAxis)))
				if across < halfLane and math.abs(along) < 30 then
					open = true
				end
			end
			if not open then
				local wall = Props.make("ShoreWall", walls, {
					Size = Vector3.new(1, height, (q - p).Magnitude + 0.6),
					CFrame = CFrame.lookAt(mid, q) + Vector3.new(0, -MapLayout.WaterDepth + height / 2, 0),
					Color = COLORS.Water,
					Transparency = 1,
				})
				wall.CastShadow = false
				wall.CanQuery = false
			end
		end
	end
end

-- Build ---------------------------------------------------------------------------

local function buildSpawn(at: CFrame)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "GameSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.CFrame = at + Vector3.new(0, 0.2, 0)
	-- Invisible and walk-through: players just appear on the path.
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
	Props.PaintTerrain(terrain)

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
	local dressing = Props.model("Dressing", land)
	local walls = Instance.new("Folder")
	walls.Name = "PerimeterWalls"

	-- Coast angles kept free of cliffs (bridges, the pier).
	local keepClear: { [string]: { number } } = {}
	for _, island in Geo.Islands do
		keepClear[island.Id] = keepClear[island.Id] or {}
		local bridge = Geo.BridgeTo(island)
		if bridge then
			table.insert(keepClear[island.Id], Geo.AngleOf(-bridge.Direction))
			table.insert(keepClear[bridge.From.Id], Geo.AngleOf(bridge.Direction))
		end
	end
	-- Docks point away from the first bridge, a bit to the side.
	local dockDir: { [string]: Vector3 } = {}
	for _, island in Geo.Islands do
		if island.Def.Dock then
			local departure = Geo.Departure(island)
			local away = if departure then (island.Center - departure).Unit else Vector3.new(0, 0, 1)
			local dir = CFrame.Angles(0, math.rad(65), 0) * away
			dockDir[island.Id] = dir
			table.insert(keepClear[island.Id], Geo.AngleOf(dir))
		end
	end
	local last = Geo.Islands[#Geo.Islands]
	local lastBridge = Geo.BridgeTo(last)
	local farDir = if lastBridge then (CFrame.Angles(0, math.rad(18), 0) * lastBridge.Direction) else Vector3.new(0, 0, -1)
	table.insert(keepClear[last.Id], Geo.AngleOf(farDir))

	-- 1. Paths and stations: per island, a path from where you arrive to
	-- where the next bridge leaves; the sell pad and the quick-travel spot
	-- by the arrival; the farmer's tool stand off to the side near the
	-- coast, with a short path to it. The first island has the player's
	-- base (the cabin) where you spawn.
	local spawnAt = CFrame.new()
	local houseAt: { [string]: Vector3 } = {}
	for _, island in Geo.Islands do
		local zone = Zones.ById[island.Id]
		local departure = Geo.Departure(island)
		local arrival: Vector3, forward: Vector3
		if island.Def.ShopAt == "House" then
			-- The base stands on the far side from the first bridge, facing it.
			local toward = if departure then (departure - island.Center).Unit else Vector3.new(0, 0, -1)
			local housePos = island.Center - toward * (island.Def.Radius * 0.42)
			local base = ShopInterior.BuildHome(land, facing(housePos, housePos + toward), "My Base")
			claim(housePos, ShopInterior.Radius - 4)
			houseAt[island.Id] = housePos
			local entrance = base:GetAttribute("Entrance") :: Vector3?
			arrival = if entrance then flatY(entrance) + toward * 2 else housePos + toward * 24
			forward = toward
			spawnAt = CFrame.lookAt(ground(arrival + toward * 6), ground(arrival + toward * 20))
			claim(arrival + toward * 6, 6) -- open space around the spawn point
		else
			arrival, forward = Geo.Arrival(island)
		end
		local right = forward:Cross(Vector3.yAxis)
		do
			local st = MapLayout.Stations.Sell
			local pos = arrival + forward * st.Forward + right * st.Side
			local cf = facing(pos, arrival + forward * st.Forward)
			Props.sellPad(zoneFolders[island.Id], cf, 0, 0)
			claim(pos + cf.LookVector * 4, 10)
		end
		do
			local st = MapLayout.Stations.Travel
			claim(arrival + forward * st.Forward + right * st.Side, st.Radius)
		end
		-- The path: arrival -> a bend near the middle -> departure (or the pier).
		local finish = departure or (last.Center + farDir * (Geo.CoastRadius(last, Geo.AngleOf(farDir)) - BEACH + 2))
		local bend = island.Center + Vector3.new(rng:NextNumber() - 0.5, 0, rng:NextNumber() - 0.5) * island.Def.Radius * 0.5
		local route = spline({ arrival - forward * 2, arrival + forward * 14, bend, finish - (finish - bend).Unit * 10, finish })
		buildPath(paths, route, MapLayout.PathWidth)
		for _, point in route do
			markDisc(blocked, point, MapLayout.PathWidth / 2 + 2)
		end

		-- The farmer's stand: off to the side of the arrival, near the coast,
		-- facing inland. Tries angles further and further round the coast
		-- until the footprint is clear of the base, props, paths and bridges.
		do
			local st = MapLayout.Stations.Farmer
			local first = if island.Index % 2 == 0 then 1 else -1
			local from = if houseAt[island.Id] then houseAt[island.Id] else arrival
			local baseAngle = Geo.AngleOf(from - island.Center)
			local pos: Vector3? = nil
			for step = 0, 16 do
				for _, side in { first, -first } do
					local angle = baseAngle + side * (st.Angle + step * 10)
					local p = island.Center + Geo.Direction(angle) * (Geo.CoastRadius(island, angle) - st.Inland)
					local nearBridge = false
					for _, other in Geo.Islands do
						local bridge = Geo.BridgeTo(other)
						if bridge and ((p - bridge.Start).Magnitude < 34 or (p - bridge.Finish).Magnitude < 34) then
							nearBridge = true
						end
					end
					if not pos and not nearBridge and isClear(p, FarmerStand.Radius) then
						pos = p
					end
				end
				if pos then
					break
				end
			end
			if not pos then
				warn(("[MowIt][Map] No clear spot for the farmer stand on %s."):format(island.Id))
				continue
			end
			local cf = facing(pos, island.Center)
			local contact = Quests.ByZone[island.Id]
			local toolIds = ShopDisplay.ToolsForZone(Geo.Order[island.Id] or 1)
			FarmerStand.Build(zoneFolders[island.Id], cf, toolIds, if contact then contact.NpcName else "Farmer", zone.ThemeColor)
			claim(pos, FarmerStand.Radius)
			-- A short path from the stand's front to the nearest point of the main path.
			local front = (pos :: Vector3) + cf.LookVector * -8
			local nearest = route[1]
			for _, point in route do
				if (point - front).Magnitude < (nearest - front).Magnitude then
					nearest = point
				end
			end
			local spur = spline({ (pos :: Vector3) + cf.LookVector * -4, front, nearest })
			buildPath(paths, spur, MapLayout.PathWidth - 2)
			for _, point in spur do
				markDisc(blocked, point, MapLayout.PathWidth / 2 + 1)
			end
		end
	end

	-- 2. Props: each island's props stand together in one cluster (a
	-- farmyard), around the first one; on the house island, around the
	-- house. Then a few clearings with a tree inside the fields.
	for _, island in Geo.Islands do
		local anchor: Vector3? = houseAt[island.Id]
		for _, name in island.Def.Props do
			local kind = Props.Kinds[name]
			if not kind then
				warn(("[MowIt][Map] Unknown prop %q in MapLayout (zone %s)."):format(name, island.Id))
				continue
			end
			local spot: Vector3? = nil
			if anchor then
				for _ = 1, 80 do
					local a = rng:NextNumber() * math.pi * 2
					local d = (if houseAt[island.Id] then ShopInterior.Radius else 8) + kind.Radius + rng:NextNumber() * 22
					local p = anchor + Vector3.new(math.cos(a), 0, math.sin(a)) * d
					if Geo.FitsIn(p, kind.Radius, island.Id, island.Def.Lawns.Rim - 6) and isClear(p, kind.Radius) then
						spot = p
						break
					end
				end
			else
				spot = propSpot(island, kind.Radius, island.Def.Lawns.Rim + 4)
				anchor = spot
			end
			if spot then
				local cf = facing(spot, anchor or island.Center)
				if (spot - (anchor :: Vector3)).Magnitude < 1 then
					cf = facing(spot, island.Center)
				end
				claim(spot, kind.Radius)
				kind.Build(dressing, cf)
			else
				warn(("[MowIt][Map] No room for %s in %s."):format(name, island.Id))
			end
		end
		for _ = 1, island.Def.Lawns.Holes do
			local spot = propSpot(island, 6, island.Def.Lawns.Rim)
			if spot then
				claim(spot, 3 + rng:NextNumber() * 4)
				for i = 1, 1 + rng:NextInteger(0, 2) do
					local offset = Vector3.new(rng:NextNumber() - 0.5, 0, rng:NextNumber() - 0.5) * 6
					Props.place(if i == 1 then "Tree" else "Bush", dressing, CFrame.new(ground(spot + offset)) * CFrame.Angles(0, rng:NextNumber() * 6.28, 0), 0.9 + rng:NextNumber() * 0.4)
				end
			end
		end
	end

	-- 3. Lawns: everything inside each island's rim, minus what was claimed.
	-- The rim wobbles so the fields look organic.
	local lawnCells: { [string]: { { Ix: number, Iz: number } } } = {}
	local lawnSet: { [string]: boolean } = {}
	local count = 0
	for _, island in Geo.Islands do
		local reach = island.Def.Radius * 1.3
		local c = island.Center
		for ix = math.floor((c.X - reach) / CELL), math.floor((c.X + reach) / CELL) do
			for iz = math.floor((c.Z - reach) / CELL), math.floor((c.Z + reach) / CELL) do
				local center = Vector3.new(ix * CELL + CELL / 2, 0, iz * CELL + CELL / 2)
				local edge = Geo.EdgeDistance(island, center)
				local angle = Geo.AngleOf(center - c)
				local rim = island.Def.Lawns.Rim + 6 * Geo.CoastNoise(island, angle, 4.1)
				if edge < -rim and not blocked[ix .. "," .. iz] then
					lawnCells[island.Id] = lawnCells[island.Id] or {}
					table.insert(lawnCells[island.Id], { Ix = ix, Iz = iz })
					lawnSet[ix .. "," .. iz] = true
					count += 1
				end
			end
		end
	end

	-- 4. Terrain: the sea first, then every island column (with its
	-- underwater slope), then lawns painted in.
	local minV, maxV = Geo.Bounds()
	local farCenter = last.Center + farDir * (last.Def.Radius + MapLayout.FarIsland.Distance + MapLayout.FarIsland.Radius)
	minV = minV:Min(farCenter - Vector3.one * MapLayout.FarIsland.Radius)
	maxV = maxV:Max(farCenter + Vector3.one * MapLayout.FarIsland.Radius)
	local margin = MapLayout.SeaMargin
	fillSea(minV.X - margin, maxV.X + margin, minV.Z - margin, maxV.Z + margin)
	local inner = margin - MapLayout.FarSeaOverlap
	buildFarSea(land, minV.X - inner, maxV.X + inner, minV.Z - inner, maxV.Z + inner)

	local done: { [string]: boolean } = {}
	local filled = 0
	for _, island in Geo.Islands do
		local reach = island.Def.Radius * 1.3 + 30
		local c = island.Center
		for ix = math.floor((c.X - reach) / CELL), math.floor((c.X + reach) / CELL) do
			for iz = math.floor((c.Z - reach) / CELL), math.floor((c.Z + reach) / CELL) do
				local k = ix .. "," .. iz
				if done[k] then
					continue
				end
				local center = Vector3.new(ix * CELL + CELL / 2, 0, iz * CELL + CELL / 2)
				local nearest, edge = Geo.Nearest(center)
				if edge > 34 then
					continue
				end
				done[k] = true
				local angle = Geo.AngleOf(center - nearest.Center)
				local y, material = surfaceAt(edge, cliffAt(nearest, angle, keepClear[nearest.Id]))
				fillColumn(center, y, material)
				filled += 1
				if filled % 600 == 0 then
					task.wait()
				end
			end
		end
	end
	for _, cells in lawnCells do
		for _, c in cells do
			local center = Vector3.new(c.Ix * CELL + CELL / 2, GROUND_TOP, c.Iz * CELL + CELL / 2)
			terrain:ReplaceMaterial(columnRegion(center), CELL, MapService.Materials.Wild, MapService.Materials.Lawn)
		end
		task.wait()
	end

	-- 5. Bridges with their gates, the last island's pier, then the shore walls.
	buildBridges(land, zoneFolders, walls)
	local openings = {}
	for _, island in Geo.Islands do
		local bridge = Geo.BridgeTo(island)
		if bridge then
			table.insert(openings, { Point = bridge.Start, Direction = bridge.Direction })
			table.insert(openings, { Point = bridge.Finish, Direction = bridge.Direction })
		end
	end
	do
		-- A short pier toward the far island, closed for now (the shore wall
		-- crosses it right past the sign).
		local coast = last.Center + farDir * Geo.CoastRadius(last, Geo.AngleOf(farDir))
		local pier = Props.model("Pier", land)
		buildBridgeDeck(pier, flatY(coast - farDir * (BEACH - 2)), flatY(coast + farDir * 26))
		local signAt = facing(coast + farDir * 2, coast - farDir * 10) + Vector3.new(0, 1.2, 0)
		Props.sign(pier, signAt, 0, 0, "MORE ISLANDS\nComing soon", COLORS.BarnRed)
		islet(land, farCenter, MapLayout.FarIsland.Radius, 18)
	end
	-- Docks: a wooden jetty with a moored rowboat, boxed in by invisible
	-- walls (the shore wall opens where it leaves the beach).
	for id, dir in dockDir do
		local island = Geo.ById[id]
		local coast = island.Center + dir * Geo.CoastRadius(island, Geo.AngleOf(dir))
		local a = coast - dir * (BEACH - 4)
		local b = coast + dir * MapLayout.DockLength
		local mid = (a + b) / 2
		local frame = CFrame.lookAt(Vector3.new(mid.X, GROUND_TOP + 0.3, mid.Z), Vector3.new(b.X, GROUND_TOP + 0.3, b.Z))
		local dock = Props.model("Dock", land)
		if not Props.fromLibrary("Dock", dock, frame, nil) then
			buildBridgeDeck(dock, flatY(a), flatY(b))
		end
		local side = dir:Cross(Vector3.yAxis)
		Props.fromLibrary("Boat", dock, CFrame.lookAt(flatY(b - dir * 8 + side * 9), flatY(b + side * 9)) + Vector3.new(0, WATER_LEVEL - 0.6, 0), nil)
		table.insert(openings, { Point = coast, Direction = dir })
		local height = MapLayout.ShoreWallHeight + MapLayout.WaterDepth
		local length = (b - coast).Magnitude + 4
		local box = CFrame.lookAt(coast + dir * (length / 2 - 2), b)
		for _, s in { -1, 1 } do
			local wall = Props.make("DockWall", walls, {
				Size = Vector3.new(3, height, length),
				CFrame = box * CFrame.new(s * (MapLayout.Bridge.Width / 2 + 2.5), -MapLayout.WaterDepth + height / 2, 0),
				Color = COLORS.Water,
				Transparency = 1,
			})
			wall.CastShadow = false
			wall.CanQuery = false
		end
		local cap = Props.make("DockWall", walls, {
			Size = Vector3.new(MapLayout.Bridge.Width + 8, height, 3),
			CFrame = box * CFrame.new(0, -MapLayout.WaterDepth + height / 2, -length / 2),
			Color = COLORS.Water,
			Transparency = 1,
		})
		cap.CastShadow = false
		cap.CanQuery = false
	end
	buildShoreWalls(walls, openings)
	walls.Parent = land

	-- 6. Trees and bushes along every island's rim (in clusters), never on
	-- lawns, paths or anything claimed.
	local trees = Props.model("Trees", land)
	local function tryPlant(kindName: string, point: Vector3, scale: number): boolean
		local k = key(point.X, point.Z)
		local island, edge = Geo.Nearest(point)
		if lawnSet[k] or blocked[k] or edge > -BEACH + 3 or not isClear(point, 2.5) then
			return false
		end
		local angle = Geo.AngleOf(point - island.Center)
		local y = surfaceAt(edge, cliffAt(island, angle, keepClear[island.Id]))
		table.insert(placed, { Position = flatY(point), Radius = 2.5 })
		Props.place(kindName, trees, CFrame.new(point.X, y, point.Z) * CFrame.Angles(0, rng:NextNumber() * 6.28, 0), scale)
		return true
	end
	for _, island in Geo.Islands do
		local def = island.Def
		for _ = 1, def.Trees do
			local angle = rng:NextNumber() * 360
			local depth = BEACH - 2 + rng:NextNumber() * (def.Lawns.Rim + 4 - BEACH)
			local point = island.Center + Geo.Direction(angle) * (Geo.CoastRadius(island, angle) - depth)
			if tryPlant("Tree", point, 0.9 + rng:NextNumber() * 0.6) then
				for _ = 1, rng:NextInteger(1, 3) do
					local a = rng:NextNumber() * math.pi * 2
					local offset = Vector3.new(math.cos(a), 0, math.sin(a)) * (4 + rng:NextNumber() * 5)
					local roll = rng:NextNumber()
					tryPlant(if roll < 0.45 then "Bush" elseif roll < 0.75 then "Flora" else "Tree", point + offset, 0.7 + rng:NextNumber() * 0.5)
				end
			end
		end
	end

	-- Boulders on the beaches and cliff edges, a few per island.
	for _, island in Geo.Islands do
		for _ = 1, math.floor(island.Def.Radius / 8) do
			local angle = rng:NextNumber() * 360
			local edge = -2 - rng:NextNumber() * (BEACH - 6)
			local p = island.Center + Geo.Direction(angle) * (Geo.CoastRadius(island, angle) + edge)
			local nearBridge = false
			for _, opening in openings do
				if (p - opening.Point).Magnitude < 26 then
					nearBridge = true
				end
			end
			if not nearBridge and isClear(p, 2) then
				local y = surfaceAt(edge, cliffAt(island, angle, keepClear[island.Id]))
				table.insert(placed, { Position = flatY(p), Radius = 2 })
				Props.place("Rock", trees, CFrame.new(p.X, y - 0.6, p.Z) * CFrame.Angles(0, rng:NextNumber() * 6.28, 0), 0.8 + rng:NextNumber() * 1.2)
			end
		end
	end

	-- 7. The sea: rocks along the coasts, wooded islets further out.
	for _ = 1, MapLayout.SeaRocks do
		local island = Geo.Islands[rng:NextInteger(1, #Geo.Islands)]
		local angle = rng:NextNumber() * 360
		local p = island.Center + Geo.Direction(angle) * (Geo.CoastRadius(island, angle) + 3 + rng:NextNumber() * 30)
		local _, edge = Geo.Nearest(p)
		local nearBridge = false
		for _, opening in openings do
			if (p - opening.Point).Magnitude < 34 then
				nearBridge = true
			end
		end
		if edge > 2 and not nearBridge then
			terrain:FillBall(Vector3.new(p.X, WATER_LEVEL - 1.5, p.Z), 2.5 + rng:NextNumber() * 4, MapService.Materials.Rock)
		end
	end
	local placedIslets = 0
	for _ = 1, MapLayout.Islets * 8 do
		if placedIslets >= MapLayout.Islets then
			break
		end
		local p = Vector3.new(minV.X - 150 + rng:NextNumber() * (maxV.X - minV.X + 300), 0, minV.Z - 150 + rng:NextNumber() * (maxV.Z - minV.Z + 300))
		local _, edge = Geo.Nearest(p)
		local clear = edge > 60 and (p - farCenter).Magnitude > MapLayout.FarIsland.Radius + 60
		for _, island in Geo.Islands do
			local bridge = Geo.BridgeTo(island)
			if bridge then
				local rel = p - bridge.Start
				local along = math.clamp(rel:Dot(bridge.Direction), 0, (bridge.Finish - bridge.Start).Magnitude)
				if (rel - bridge.Direction * along).Magnitude < 50 then
					clear = false
				end
			end
		end
		if clear then
			islet(trees, p, 10 + rng:NextNumber() * 16, rng:NextInteger(1, 4))
			placedIslets += 1
		end
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
	buildSpawn(spawnAt)
	print(("[MowIt][Map] Land built: %d lawn cells on %d islands."):format(count, #Geo.Islands))
end

-- Edit-mode "bake": run from the Command Bar (or Studio MCP) to build the
-- land into the place so it can be edited by hand and saved:
--   require(game.ServerScriptService.Services.MapService).Bake()
-- Does nothing if Workspace/Zones already exists. See docs/EDITING.md.
function MapService.Bake()
	MapService.BuildIfMissing()
end

return MapService
