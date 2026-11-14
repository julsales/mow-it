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
local HayYardConfig = require(Shared.Config.HayYard)

local Props = require(script.Parent.Map.Props)
local ShopDisplay = require(script.Parent.Map.ShopDisplay)
local ShopInterior = require(script.Parent.Map.ShopInterior)
local FarmerStand = require(script.Parent.Map.FarmerStand)
local HayYard = require(script.Parent.Map.HayYard)
local Bases = require(script.Parent.Map.Bases)
local BasesConfig = require(Shared.Config.Bases)
local TravelConfig = require(Shared.Config.Travel)
local SharedBases = require(Shared.Bases)
local Geo = require(script.Parent.Map.MapGeometry)
local LawnCells = require(Shared.LawnCells)

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
-- with round caps at the joints and a few small rocks along the edges.
local PATH_COLOR = Color3.fromRGB(214, 176, 122)

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
			-- A small low-poly rock beside the path (library "Rock").
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local at = frame * CFrame.new(side * (width / 2 + 0.6), -0.1, 0) * CFrame.Angles(0, rng:NextNumber() * 6.28, 0)
			Props.place("Rock", folder, at, 0.25 + rng:NextNumber() * 0.2)
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
-- `beach` = width of the sand band (default: MapLayout.Beach).
local function surfaceAt(edge: number, cliff: number, beach: number?): (number, Enum.Material)
	local BEACH = beach or BEACH
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

-- A small wooded islet: a grassy hill on a sand foot (terrain only).
local function isletTerrain(center: Vector3, radius: number)
	terrain:FillBall(Vector3.new(center.X, WATER_LEVEL - radius * 0.9, center.Z), radius * 1.15, MapService.Materials.Beach)
	terrain:FillBall(Vector3.new(center.X, WATER_LEVEL - radius * 0.5, center.Z), radius * 0.85, MapService.Materials.Wild)
end

-- Trees on an islet's hilltop (Bake only; Restamp leaves them alone).
local function isletTrees(parent: Instance, center: Vector3, radius: number, trees: number, r: Random)
	for _ = 1, trees do
		local a = r:NextNumber() * math.pi * 2
		local d = math.sqrt(r:NextNumber()) * radius * 0.4
		local x, z = center.X + math.cos(a) * d, center.Z + math.sin(a) * d
		local rr = radius * 0.85
		local y = WATER_LEVEL - radius * 0.5 + math.sqrt(math.max(rr * rr - d * d, 0)) - 0.3
		if y > WATER_LEVEL + 1 then
			Props.place("Tree", parent, CFrame.new(x, y, z) * CFrame.Angles(0, r:NextNumber() * 6.28, 0), 0.8 + r:NextNumber() * 0.6)
		end
	end
end

-- The coast plan, worked out from the layout alone (same every time):
-- coast angles kept free of cliffs (bridges, docks, the pier), where docks
-- and the pier point, the far island, and the openings in the shore walls.
type Opening = { Point: Vector3, Direction: Vector3 }
type Plan = {
	KeepClear: { [string]: { number } },
	Jetties: { [string]: { Coast: Vector3, Direction: Vector3 } }, -- island id -> where its jetty leaves the coast
	FarDir: Vector3,
	FarCenter: Vector3,
	Openings: { Opening },
	Islets: { { Center: Vector3, Radius: number, Trees: number } },
	SeaRocks: { { IslandId: string, Point: Vector3, Radius: number } },
	Min: Vector3,
	Max: Vector3,
}

local function coastPlan(): Plan
	local keepClear: { [string]: { number } } = {}
	local openings: { Opening } = {}
	for _, island in Geo.Islands do
		keepClear[island.Id] = keepClear[island.Id] or {}
		local bridge = Geo.BridgeTo(island)
		if bridge then
			table.insert(keepClear[island.Id], Geo.AngleOf(-bridge.Direction))
			table.insert(keepClear[bridge.From.Id], Geo.AngleOf(bridge.Direction))
			table.insert(openings, { Point = bridge.Start, Direction = bridge.Direction })
			table.insert(openings, { Point = bridge.Finish, Direction = bridge.Direction })
		end
	end
	-- Jetties (boat travel, Config/Travel): on every island a bridge leads
	-- onto, a little way round the coast from where it arrives, on the
	-- side away from the drop-off pad. No cliff there; the shore wall opens.
	local jetties: { [string]: { Coast: Vector3, Direction: Vector3 } } = {}
	for _, island in Geo.Islands do
		local bridge = Geo.BridgeTo(island)
		if bridge then
			local arrival = Geo.AngleOf(bridge.Finish - island.Center)
			local turn = math.deg(TravelConfig.Jetty.Along / island.Def.Radius)
			local right = bridge.Direction:Cross(Vector3.yAxis)
			local padSide = if MapLayout.Stations.Sell.Side >= 0 then 1 else -1
			local angle = arrival + turn
			if (Geo.Direction(angle) - Geo.Direction(arrival)):Dot(right) * padSide > 0 then
				angle = arrival - turn
			end
			local dir = Geo.Direction(angle)
			local coast = island.Center + dir * Geo.CoastRadius(island, angle)
			jetties[island.Id] = { Coast = coast, Direction = dir }
			table.insert(keepClear[island.Id], angle)
			table.insert(openings, { Point = coast, Direction = dir })
		end
	end
	local last = Geo.Islands[#Geo.Islands]
	local lastBridge = Geo.BridgeTo(last)
	local farDir = if lastBridge then (CFrame.Angles(0, math.rad(18), 0) * lastBridge.Direction) else Vector3.new(0, 0, -1)
	table.insert(keepClear[last.Id], Geo.AngleOf(farDir))
	local farCenter = last.Center + farDir * (last.Def.Radius + MapLayout.FarIsland.Distance + MapLayout.FarIsland.Radius)

	local minV, maxV = Geo.Bounds()
	minV = minV:Min(farCenter - Vector3.one * MapLayout.FarIsland.Radius)
	maxV = maxV:Max(farCenter + Vector3.one * MapLayout.FarIsland.Radius)

	-- The personal bases around the home island: their bridges open its
	-- shore wall, and sea rocks and islets keep out of their water.
	for _, opening in Bases.Openings() do
		table.insert(openings, opening)
	end
	for _, slot in Bases.Slots do
		table.insert(keepClear[Geo.Islands[1].Id], slot.Heading) -- no cliff where a base's bridge lands
	end

	-- Rocks in the shallows and wooded islets (own seeded Random, so the
	-- same spots come back on every Restamp).
	local r = Random.new(MapLayout.Seed + 7)
	local rocks = {}
	for _ = 1, MapLayout.SeaRocks do
		local island = Geo.Islands[r:NextInteger(1, #Geo.Islands)]
		local angle = r:NextNumber() * 360
		local p = island.Center + Geo.Direction(angle) * (Geo.CoastRadius(island, angle) + 3 + r:NextNumber() * 30)
		local radius = 2.5 + r:NextNumber() * 4
		local _, edge = Geo.Nearest(p)
		local nearOpening = false
		for _, opening in openings do
			if (p - opening.Point).Magnitude < 34 then
				nearOpening = true
			end
		end
		if edge > 2 and not nearOpening and not Bases.Near(p, 14) then
			table.insert(rocks, { IslandId = island.Id, Point = p, Radius = radius })
		end
	end
	local islets = {}
	for _ = 1, MapLayout.Islets * 8 do
		if #islets >= MapLayout.Islets then
			break
		end
		local p = Vector3.new(minV.X - 150 + r:NextNumber() * (maxV.X - minV.X + 300), 0, minV.Z - 150 + r:NextNumber() * (maxV.Z - minV.Z + 300))
		local radius, trees = 10 + r:NextNumber() * 16, r:NextInteger(1, 4)
		local _, edge = Geo.Nearest(p)
		local clear = edge > 60 and (p - farCenter).Magnitude > MapLayout.FarIsland.Radius + 60 and not Bases.Near(p, 50)
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
			table.insert(islets, { Center = p, Radius = radius, Trees = trees })
		end
	end
	return {
		KeepClear = keepClear,
		Jetties = jetties,
		FarDir = farDir,
		FarCenter = farCenter,
		Openings = openings,
		Islets = islets,
		SeaRocks = rocks,
		Min = minV,
		Max = maxV,
	}
end

local kit: () -> Bases.Kit

-- One island's ground columns. For every terrain cell around where the
-- island now is, look up the baked spot it came from (inverse of the move
-- `delta`) and copy that ground: grid-aligned, no gaps, works for turned
-- islands. `done` = cells already filled (by an island stamped earlier).
local function stampIsland(island: Geo.Island, delta: CFrame, plan: Plan, done: { [string]: boolean })
	local filled = 0
	local bottom = -MapLayout.WaterDepth - 6
	local back = delta:Inverse()
	local reach = island.Def.Radius * 1.3 + 30
	local c = delta * island.Center
	for ix = math.floor((c.X - reach) / CELL), math.floor((c.X + reach) / CELL) do
		for iz = math.floor((c.Z - reach) / CELL), math.floor((c.Z + reach) / CELL) do
			local k = ix .. "," .. iz
			if done[k] then
				continue
			end
			local center = Vector3.new(ix * CELL + CELL / 2, 0, iz * CELL + CELL / 2)
			local source = back * center
			local nearest, edge = Geo.Nearest(Vector3.new(source.X, 0, source.Z))
			if nearest ~= island or edge > 34 then
				continue
			end
			done[k] = true
			local angle = Geo.AngleOf(source - nearest.Center)
			local top, material = surfaceAt(edge, cliffAt(nearest, angle, plan.KeepClear[nearest.Id]))
			top += delta.Position.Y
			local height = top - SURFACE_LIFT - bottom
			if height > 0 then
				terrain:FillBlock(CFrame.new(center.X, bottom + height / 2, center.Z), Vector3.new(CELL, height, CELL), material)
			end
			filled += 1
			if filled % 600 == 0 then
				task.wait()
			end
		end
	end
end

-- All the terrain: sea, islands, rocks, islets, then the lawns painted in
-- under every GrassArea. `moved[islandId]` = how far that island's Model
-- was moved since the bake (a CFrame); its ground is stamped there.
local function stampTerrain(moved: { [string]: CFrame }, movedBases: { [string]: CFrame })
	local plan = coastPlan()
	terrain:Clear()
	local minV, maxV = plan.Min, plan.Max
	for _, island in Geo.Islands do
		local delta = moved[island.Id] or CFrame.identity
		local r = island.Def.Radius * 1.3 + 40
		local c = delta * island.Center
		minV = minV:Min(c - Vector3.new(r, 0, r))
		maxV = maxV:Max(c + Vector3.new(r, 0, r))
	end
	local margin = MapLayout.SeaMargin
	fillSea(minV.X - margin, maxV.X + margin, minV.Z - margin, maxV.Z + margin)

	local done: { [string]: boolean } = {}
	for _, island in Geo.Islands do
		stampIsland(island, moved[island.Id] or CFrame.identity, plan, done)
	end
	for _, rock in plan.SeaRocks do
		local p = (moved[rock.IslandId] or CFrame.identity) * rock.Point
		terrain:FillBall(Vector3.new(p.X, WATER_LEVEL - 1.5, p.Z), rock.Radius, MapService.Materials.Rock)
	end
	for _, spot in plan.Islets do
		isletTerrain(spot.Center, spot.Radius)
	end
	isletTerrain(plan.FarCenter, MapLayout.FarIsland.Radius)
	Bases.Stamp(kit(), movedBases)

	-- Lawns: wherever the GrassArea parts are now.
	local painted = 0
	for _, cell in LawnCells.Collect() do
		terrain:ReplaceMaterial(columnRegion(cell.Center), CELL, MapService.Materials.Wild, MapService.Materials.Lawn)
		painted += 1
		if painted % 800 == 0 then
			task.wait()
		end
	end
end

-- Bridges and gates -------------------------------------------------------------------

local BRIDGE_ARCH = 2.5

local function bridgeDeckY(t: number, arch: number?): number
	-- A gentle arch: ends on the beaches, `arch` studs higher in the middle.
	return GROUND_TOP + 0.4 + math.sin(math.pi * math.clamp(t, 0, 1)) * (arch or BRIDGE_ARCH)
end

-- A wooden bridge from `a` to `b` (points at y = 0): deck, rails, posts,
-- piles; `deckWidth` defaults to the island bridges' width, `arch` to
-- their rise in the middle (0 = a flat jetty).
local function buildBridgeDeck(folder: Instance, a: Vector3, b: Vector3, deckWidth: number?, arch: number?)
	local width = deckWidth or MapLayout.Bridge.Width
	local dir = (b - a).Unit
	local length = (b - a).Magnitude
	local count = math.max(2, math.ceil(length / 4))
	for i = 0, count - 1 do
		local t0, t1 = i / count, (i + 1) / count
		local p0 = a + dir * length * t0 + Vector3.new(0, bridgeDeckY(t0, arch), 0)
		local p1 = a + dir * length * t1 + Vector3.new(0, bridgeDeckY(t1, arch), 0)
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

-- Invisible walls along both sides of a lane `width` wide from `wa` to
-- `wb` (bridges: nobody jumps into the water).
local function buildCorridor(parent: Instance, wa: Vector3, wb: Vector3, width: number)
	local mid = (wa + wb) / 2
	local along = CFrame.lookAt(mid, mid + (wb - wa).Unit)
	local height = MapLayout.ShoreWallHeight + MapLayout.WaterDepth
	for _, side in { -1, 1 } do
		local wall = Props.make("BridgeWall", parent, {
			Size = Vector3.new(3, height, (wb - wa).Magnitude),
			CFrame = along * CFrame.new(side * (width / 2 + 1.5), -MapLayout.WaterDepth + height / 2, 0),
			Color = COLORS.Water,
			Transparency = 1,
		})
		wall.CastShadow = false
		wall.CanQuery = false
	end
end

-- Every bridge: deck from beach to beach, invisible side walls (no jumping
-- into the water), and the area's gate in the middle (contract ZoneGate;
-- ZoneWall above it so nobody jumps over).
local function buildBridges(islandModels: { [string]: Model })
	for _, island in Geo.Islands do
		local bridge = Geo.BridgeTo(island)
		if not bridge then
			continue
		end
		local zone = Zones.ById[island.Id]
		-- The bridge that leads ONTO this island belongs to it (with its gate).
		local folder = Props.model("Bridge", islandModels[island.Id])
		local a = bridge.Start - bridge.Direction * (BEACH - 2)
		local b = bridge.Finish + bridge.Direction * (BEACH - 2)
		buildBridgeDeck(folder, a, b)

		-- Corridor walls along both sides, from coast to coast and a bit inland.
		buildCorridor(folder, bridge.Start - bridge.Direction * 6, bridge.Finish + bridge.Direction * 6, MapLayout.Bridge.Width)

		-- The gate in the middle of the bridge, under an arch with the name.
		local deckTop = bridge.Gate + Vector3.new(0, bridgeDeckY(0.5) + 0.3, 0)
		local gateFrame = CFrame.lookAt(deckTop, deckTop + bridge.Direction)
		local gate = Props.make("ZoneGate", folder, {
			Size = Vector3.new(MapLayout.GateWidth, MapLayout.WallHeight, 0.6),
			CFrame = gateFrame * CFrame.new(0, MapLayout.WallHeight / 2, 0),
			Color = zone.ThemeColor,
			Material = Enum.Material.Glass,
			Transparency = 0.35,
		})
		local text = ("LOCKED\n%s\n%s · Lv %d"):format(zone.DisplayName, Format.Coins(zone.UnlockPrice), zone.RequiredLevel)
		Props.label(gate, Enum.NormalId.Front, text, Color3.new(1, 1, 1))
		Props.label(gate, Enum.NormalId.Back, text, Color3.new(1, 1, 1))
		local above = Props.make("ZoneWall", folder, {
			Size = Vector3.new(MapLayout.GateWidth + 2, MapLayout.ShoreWallHeight, 0.6),
			CFrame = gateFrame * CFrame.new(0, MapLayout.WallHeight + MapLayout.ShoreWallHeight / 2, 0),
			Color = zone.ThemeColor,
			Transparency = 1,
		})
		above.CastShadow = false
		above.CanQuery = false
		above:SetAttribute("ZoneId", island.Id)
		Props.gateArch(folder, gateFrame, MapLayout.Bridge.Width, MapLayout.WallHeight, zone.DisplayName, zone.ThemeColor)
		folder.WorldPivot = gateFrame
	end
end

-- A dock: a wooden jetty with a moored rowboat leaving the coast at
-- `coast` toward `dir`, boxed in by invisible walls (the shore wall opens
-- where it leaves the beach); the deck starts `inland` studs in from the
-- coast. The library jetty is made for
-- MapLayout.DockLength; other lengths scale it.
local function buildDock(parent: Instance, coast: Vector3, dir: Vector3, length: number, inland: number): Model
	local scale = length / MapLayout.DockLength
	local a = coast - dir * inland
	local b = coast + dir * length
	local mid = (a + b) / 2
	local frame = CFrame.lookAt(Vector3.new(mid.X, GROUND_TOP + 0.3, mid.Z), Vector3.new(b.X, GROUND_TOP + 0.3, b.Z))
	local dock = Props.model("Dock", parent)
	dock.WorldPivot = frame
	local width = MapLayout.Bridge.Width * scale
	if not Props.fromLibrary("Dock", dock, frame, scale) then
		buildBridgeDeck(dock, flatY(a), flatY(b), width, 0)
	end
	local side = dir:Cross(Vector3.yAxis)
	local berth = side * 12 * scale
	Props.fromLibrary("Boat", dock, CFrame.lookAt(flatY(b - dir * 8 * scale + berth), flatY(b + berth)) + Vector3.new(0, WATER_LEVEL - 1, 0), scale)
	local height = MapLayout.ShoreWallHeight + MapLayout.WaterDepth
	local boxLength = (b - coast).Magnitude + 4
	local box = CFrame.lookAt(coast + dir * (boxLength / 2 - 2), b)
	for _, s in { -1, 1 } do
		local wall = Props.make("DockWall", dock, {
			Size = Vector3.new(3, height, boxLength),
			CFrame = box * CFrame.new(s * (width / 2 + 2.5), -MapLayout.WaterDepth + height / 2, 0),
			Color = COLORS.Water,
			Transparency = 1,
		})
		wall.CastShadow = false
		wall.CanQuery = false
	end
	local cap = Props.make("DockWall", dock, {
		Size = Vector3.new(width + 8, height, 3),
		CFrame = box * CFrame.new(0, -MapLayout.WaterDepth + height / 2, -boxLength / 2),
		Color = COLORS.Water,
		Transparency = 1,
	})
	cap.CastShadow = false
	cap.CanQuery = false
	return dock
end

-- An island's jetty for boat travel (contract Model "Jetty", Shared/Jetties).
local function buildJetty(islandModel: Instance, jetty: { Coast: Vector3, Direction: Vector3 }): Model
	-- The deck starts on the grass, just past the top of the beach.
	local dock = buildDock(islandModel, jetty.Coast, jetty.Direction, TravelConfig.Jetty.Length, BEACH + 1)
	dock.Name = "Jetty"
	return dock
end

-- Invisible walls just offshore around every island, open where bridges
-- (and the last island's pier) leave the coast.
local function buildShoreWalls(islandModels: { [string]: Model }, openings: { { Point: Vector3, Direction: Vector3 } })
	local height = MapLayout.ShoreWallHeight + MapLayout.WaterDepth
	local halfLane = MapLayout.Bridge.Width / 2 + 1
	for _, island in Geo.Islands do
		if not islandModels[island.Id] then
			continue
		end
		local walls = Props.model("ShoreWalls", islandModels[island.Id])
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

local function buildSpawn(at: CFrame, parent: Instance, name: string?): SpawnLocation
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = name or "GameSpawn"
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
	spawn.Parent = parent
	return spawn
end

-- The generic builders the personal bases are made with (Map/Bases).
function kit(): Bases.Kit
	return {
		BridgeDeck = buildBridgeDeck,
		Corridor = buildCorridor,
		Path = buildPath,
		Dock = buildDock,
		Spawn = buildSpawn,
		SurfaceAt = surfaceAt,
		WaterTop = WATER_LEVEL - SURFACE_LIFT,
		Bottom = -MapLayout.WaterDepth - 6,
		SurfaceLift = SURFACE_LIFT,
	}
end

-- The promenade on the home island: a dirt path all the way round, a
-- little in from the coast, passing the foot of every base's bridge and
-- of the bridge to the next island.
local function promenadeRoute(): { Vector3 }
	local home = Geo.Islands[1]
	local inland = BasesConfig.Promenade.Inland
	local points = {}
	for angle = 0, 360, 8 do
		table.insert(points, home.Center + Geo.Direction(angle) * (Geo.CoastRadius(home, angle) - inland))
	end
	return spline(points)
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
	-- Hierarchy (docs/EDITING.md "Moving things"): Workspace/Zones/<id> is
	-- one Model per island holding everything on it, each piece its own
	-- Model; Workspace/Sea holds the water dressing around them.
	local land = Instance.new("Folder")
	land.Name = "Sea"
	land.Parent = Workspace
	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	local islandModels: { [string]: Model } = {}
	local pathModels: { [string]: Model } = {}
	local yardModels: { [string]: Model } = {}
	local treeModels: { [string]: Model } = {}
	for _, zone in Zones.List do
		local island = Geo.ById[zone.Id]
		if not island then
			warn(("[MowIt][Map] No MapLayout row for zone %q."):format(zone.Id))
			continue
		end
		local m = Instance.new("Model")
		m.Name = zone.Id
		local pivot = CFrame.new(island.Center.X, GROUND_TOP, island.Center.Z)
		m.WorldPivot = pivot
		-- Where the island was baked: Restamp() moves its terrain by how far
		-- the Model has been moved since.
		m:SetAttribute("BakedPivot", pivot)
		m.Parent = zonesFolder
		islandModels[zone.Id] = m
		pathModels[zone.Id] = Props.model("Path", m)
		yardModels[zone.Id] = Props.model(if island.Def.ShopAt == "House" then "Yard" else "Farmyard", m)
		treeModels[zone.Id] = Props.model("Trees", m)
	end

	local plan = coastPlan()
	local keepClear, farDir, farCenter = plan.KeepClear, plan.FarDir, plan.FarCenter
	local last = Geo.Islands[#Geo.Islands]

	-- 1. Paths and stations: per island, a path from where you arrive to
	-- where the next bridge leaves; the sell pad and the quick-travel spot
	-- by the arrival; the farmer's tool stand off to the side near the
	-- coast, with a short path to it. The first island has the player's
	-- base (the cabin) where you spawn.
	local spawnAt = CFrame.new()
	local homeModel: Model? = nil
	local homeRoute: { Vector3 }? = nil
	local houseAt: { [string]: Vector3 } = {}
	for _, island in Geo.Islands do
		local zone = Zones.ById[island.Id]
		local departure = Geo.Departure(island)
		local arrival: Vector3, forward: Vector3
		if island.Def.ShopAt == "House" then
			-- The home island is everybody's: cabins and hay yards stand on
			-- the personal bases around it (Map/Bases). Its path starts on
			-- the far side from the first bridge, where players who have no
			-- base appear; its only path is the promenade round its coast,
			-- which every bridge lands on.
			local toward = if departure then (departure - island.Center).Unit else Vector3.new(0, 0, -1)
			arrival = island.Center
			forward = toward
			homeModel = islandModels[island.Id]
			spawnAt = CFrame.lookAt(ground(arrival), ground(arrival + toward * 20))
			claim(arrival, 6) -- open space around the spawn point
			homeRoute = promenadeRoute()
			local walk = Props.model("Promenade", islandModels[island.Id])
			buildPath(walk, homeRoute, BasesConfig.Promenade.Width)
			walk.WorldPivot = pathModels[island.Id].WorldPivot
			for _, point in homeRoute do
				markDisc(blocked, point, BasesConfig.Promenade.Width / 2 + 2)
			end
		else
			arrival, forward = Geo.Arrival(island)
		end
		local right = forward:Cross(Vector3.yAxis)
		do
			local st = MapLayout.Stations.Sell
			local pos = arrival + forward * st.Forward + right * st.Side
			local cf = facing(pos, arrival + forward * st.Forward)
			-- Hay yards are on the personal bases; every island past the
			-- home one has a drop-off pad that sends grass to its player's.
			if island.Def.ShopAt ~= "House" then
				local station = Props.model("SellStation", islandModels[island.Id])
				Props.sellPad(station, cf, 0, 0)
				station.WorldPivot = cf
				claim(pos + cf.LookVector * 4, 10)
			end
		end
		do
			local st = MapLayout.Stations.Travel
			claim(arrival + forward * st.Forward + right * st.Side, st.Radius)
		end
		-- The path: arrival -> a bend near the middle -> departure (or the pier).
		local finish = departure or (last.Center + farDir * (Geo.CoastRadius(last, Geo.AngleOf(farDir)) - BEACH + 2))
		local bend = island.Center + Vector3.new(rng:NextNumber() - 0.5, 0, rng:NextNumber() - 0.5) * island.Def.Radius * 0.5
		local route = spline({ arrival - forward * 2, arrival + forward * 14, bend, finish - (finish - bend).Unit * 10, finish })
		local paths = pathModels[island.Id]
		if island.Def.ShopAt == "House" and homeRoute then
			route = homeRoute -- the home island's only path is its promenade
		else
			buildPath(paths, route, MapLayout.PathWidth)
			for _, point in route do
				markDisc(blocked, point, MapLayout.PathWidth / 2 + 2)
			end
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
			FarmerStand.Build(islandModels[island.Id], cf, toolIds, if contact then contact.NpcName else "Farmer", zone.ThemeColor)
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
				kind.Build(yardModels[island.Id], cf)
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
					Props.place(if i == 1 then "Tree" else "Bush", treeModels[island.Id], CFrame.new(ground(spot + offset)) * CFrame.Angles(0, rng:NextNumber() * 6.28, 0), 0.9 + rng:NextNumber() * 0.4)
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

	-- 4. The far sea plates (the terrain itself is stamped at the end).
	do
		local inner = MapLayout.SeaMargin - MapLayout.FarSeaOverlap
		local minV, maxV = plan.Min, plan.Max
		buildFarSea(land, minV.X - inner, maxV.X + inner, minV.Z - inner, maxV.Z + inner)
	end

	-- 5. Bridges with their gates, the last island's pier, then the shore walls.
	buildBridges(islandModels)
	local openings = plan.Openings
	do
		-- A short pier toward the far island, closed for now (the shore wall
		-- crosses it right past the sign).
		local coast = last.Center + farDir * Geo.CoastRadius(last, Geo.AngleOf(farDir))
		local pier = Props.model("Pier", islandModels[last.Id])
		buildBridgeDeck(pier, flatY(coast - farDir * (BEACH - 2)), flatY(coast + farDir * 26))
		local signAt = facing(coast + farDir * 2, coast - farDir * 10) + Vector3.new(0, 1.2, 0)
		Props.sign(pier, signAt, 0, 0, "MORE ISLANDS\nComing soon", COLORS.BarnRed)
		isletTrees(Props.model("FarIsland", land), farCenter, MapLayout.FarIsland.Radius, 18, Random.new(MapLayout.Seed + 9))
	end
	for id, jetty in plan.Jetties do
		buildJetty(islandModels[id], jetty)
		claim(jetty.Coast - jetty.Direction * (BEACH + 2), 6)
	end
	buildShoreWalls(islandModels, openings)

	-- 6. Trees and bushes along every island's rim (in clusters), never on
	-- lawns, paths or anything claimed.
	local function tryPlant(kindName: string, point: Vector3, scale: number): boolean
		local k = key(point.X, point.Z)
		local island, edge = Geo.Nearest(point)
		if lawnSet[k] or blocked[k] or edge > -BEACH + 3 or not isClear(point, 2.5) then
			return false
		end
		local angle = Geo.AngleOf(point - island.Center)
		local y = surfaceAt(edge, cliffAt(island, angle, keepClear[island.Id]))
		table.insert(placed, { Position = flatY(point), Radius = 2.5 })
		Props.place(kindName, treeModels[island.Id], CFrame.new(point.X, y, point.Z) * CFrame.Angles(0, rng:NextNumber() * 6.28, 0), scale)
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
				Props.place("Rock", treeModels[island.Id], CFrame.new(p.X, y - 0.6, p.Z) * CFrame.Angles(0, rng:NextNumber() * 6.28, 0), 0.8 + rng:NextNumber() * 1.2)
			end
		end
	end

	-- 7. Trees on the wooded islets out in the water.
	do
		local r = Random.new(MapLayout.Seed + 9)
		for _, spot in plan.Islets do
			isletTrees(Props.model("Islet", land), spot.Center, spot.Radius, spot.Trees, r)
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
		lawns.Parent = islandModels[zoneId]
	end

	zonesFolder.Parent = Workspace
	buildSpawn(spawnAt, homeModel or Workspace)
	Bases.Build(kit())
	stampTerrain({}, {})
	print(("[MowIt][Map] Land built: %d lawn cells on %d islands."):format(count, #Geo.Islands))
end

-- After moving island Models by hand in Studio: rebuilds ALL the terrain
-- (sea, every island's ground, rocks, islets) with each island's ground
-- under its Model's new position, and paints lawn under every GrassArea.
-- Run from the Command Bar in Edit mode, then Ctrl+S:
--   require(game.ServerScriptService.Services.MapService).Restamp()
-- Hand-painted terrain is lost (it is regenerated). Never runs in game.
function MapService.Restamp()
	local zones = Workspace:FindFirstChild("Zones")
	local moved: { [string]: CFrame } = {}
	for _, island in Geo.Islands do
		local m = zones and zones:FindFirstChild(island.Id)
		local baked = m and m:GetAttribute("BakedPivot")
		if m and m:IsA("Model") and typeof(baked) == "CFrame" then
			moved[island.Id] = m:GetPivot() * baked:Inverse()
		end
	end
	stampTerrain(moved, Bases.Moved())
end

-- Redraws ONE island's ground where its Model stands (after changing its
-- row in MapLayout, e.g. `Radius` or `Wobble`), leaving the rest of the
-- terrain alone: its old ground goes back to sea first, then the island,
-- its sea rocks, the personal bases next to it and the lawns are stamped.
--   require(game.ServerScriptService.Services.MapService).RestampIsland("front_yard")
function MapService.RestampIsland(islandId: string)
	local island = Geo.ById[islandId]
	local model = Workspace:FindFirstChild("Zones") and Workspace.Zones:FindFirstChild(islandId)
	if not island or not model or not model:IsA("Model") then
		return
	end
	local baked = model:GetAttribute("BakedPivot")
	local delta = if typeof(baked) == "CFrame" then model:GetPivot() * baked:Inverse() else CFrame.identity
	local back = delta:Inverse()
	local plan = coastPlan()
	local tools = kit()
	local reach = island.Def.Radius * 1.3 + 44
	local c = delta * island.Center
	local floorTop = -MapLayout.WaterDepth
	local cleared = 0
	for ix = math.floor((c.X - reach) / CELL), math.floor((c.X + reach) / CELL) do
		for iz = math.floor((c.Z - reach) / CELL), math.floor((c.Z + reach) / CELL) do
			local center = Vector3.new(ix * CELL + CELL / 2, 0, iz * CELL + CELL / 2)
			local nearest, edge = Geo.Nearest(back * center)
			if nearest == island and edge <= 44 then
				terrain:FillBlock(CFrame.new(center.X, tools.Bottom + 28, center.Z), Vector3.new(CELL, 56, CELL), Enum.Material.Air)
				terrain:FillBlock(CFrame.new(center.X, (tools.Bottom + tools.WaterTop) / 2, center.Z), Vector3.new(CELL, tools.WaterTop - tools.Bottom, CELL), Enum.Material.Water)
				terrain:FillBlock(CFrame.new(center.X, (tools.Bottom - 2 + floorTop) / 2, center.Z), Vector3.new(CELL, floorTop - tools.Bottom + 2, CELL), MapService.Materials.Beach)
				cleared += 1
				if cleared % 400 == 0 then
					task.wait()
				end
			end
		end
	end
	stampIsland(island, delta, plan, {})
	for _, rock in plan.SeaRocks do
		if rock.IslandId == islandId then
			local p = delta * rock.Point
			terrain:FillBall(Vector3.new(p.X, WATER_LEVEL - 1.5, p.Z), rock.Radius, MapService.Materials.Rock)
		end
	end
	Bases.Stamp(tools, Bases.Moved())
	for _, cell in LawnCells.Collect() do
		terrain:ReplaceMaterial(columnRegion(cell.Center), CELL, MapService.Materials.Wild, MapService.Materials.Lawn)
	end
end

-- Edit-mode "bake": run from the Command Bar (or Studio MCP) to build the
-- land into the place so it can be edited by hand and saved:
--   require(game.ServerScriptService.Services.MapService).Bake()
-- Does nothing if Workspace/Zones already exists. See docs/EDITING.md.
function MapService.Bake()
	MapService.BuildIfMissing()
end

-- For a place baked before boat travel existed (Edit mode, then Ctrl+S):
--   require(game.ServerScriptService.Services.MapService).BakeJetties()
-- Builds the missing island jetties and reopens those islands' shore walls
-- there. Returns where they were built, so trees or rocks standing in the
-- way can be moved by hand.
function MapService.BakeJetties(): { [string]: Vector3 }
	local zones = Workspace:FindFirstChild("Zones")
	local plan = coastPlan()
	local built = {}
	for id, jetty in plan.Jetties do
		local island = zones and zones:FindFirstChild(id)
		if island and island:IsA("Model") and not island:FindFirstChild("Jetty") then
			buildJetty(island, jetty)
			local walls = island:FindFirstChild("ShoreWalls")
			if walls then
				walls:Destroy()
			end
			buildShoreWalls({ [id] = island }, plan.Openings)
			built[id] = jetty.Coast
		end
	end
	return built
end

-- For a place baked before personal bases existed (Edit mode, then Ctrl+S):
--   require(game.ServerScriptService.Services.MapService).BakeBases()
-- Builds Workspace/Bases around the home island and its ground, the
-- promenade to their bridges, and a spawn for players without a base. The
-- home island's own cabin, hay yard and dock leave for ServerStorage
-- (`<Name>_<zone>_backup`), and its shore wall is rebuilt, open at the
-- new bridges.
-- Does nothing when the bases already exist.
function MapService.BakeBases()
	local zones = Workspace:FindFirstChild("Zones")
	local home = zones and zones:FindFirstChild(Geo.Islands[1].Id)
	if not home or SharedBases.Folder() then
		return
	end
	rng = Random.new(MapLayout.Seed + 21)
	local spawnAt: CFrame? = nil
	local oldSpawn = home:FindFirstChild("GameSpawn", true)
	if oldSpawn and oldSpawn:IsA("BasePart") then
		spawnAt = oldSpawn.CFrame - Vector3.new(0, oldSpawn.Size.Y / 2, 0)
	end
	for _, name in { "PlayerBase", "HayYard", "Dock" } do
		local piece = home:FindFirstChild(name)
		if piece then
			piece.Name = ("%s_%s_backup"):format(name, home.Name)
			piece.Parent = game:GetService("ServerStorage")
		end
	end
	if spawnAt and not home:FindFirstChild("GameSpawn", true) then
		buildSpawn(spawnAt, home)
	end

	Bases.Build(kit())
	if not home:FindFirstChild("Promenade") then
		buildPath(Props.model("Promenade", home), promenadeRoute(), BasesConfig.Promenade.Width)
	end

	-- The home island's shore wall, rebuilt open at the bases' bridges (and
	-- closed where its dock was).
	local walls = home:FindFirstChild("ShoreWalls")
	if walls then
		walls:Destroy()
	end
	buildShoreWalls({ [home.Name] = home :: Model }, coastPlan().Openings)
	Bases.Stamp(kit(), {})
	for _, cell in LawnCells.Collect() do
		terrain:ReplaceMaterial(columnRegion(cell.Center), CELL, MapService.Materials.Wild, MapService.Materials.Lawn)
	end
	print(("[MowIt][Map] %d personal bases built."):format(#Bases.Slots))
end

return MapService
