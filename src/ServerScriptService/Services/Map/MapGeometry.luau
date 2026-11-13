--!strict
-- The shape of the land, as pure math (no instances). The land is laid out
-- along one road (Shared/Config/MapLayout.luau): every ground point is
-- described by road coordinates (s, d):
--   s = distance along the road from its start (the house porch is s = 0),
--   d = signed distance from the road's center line (+ = right side when
--       walking away from the house).
-- An area is a stretch [start, finish) of s; its land reaches HalfWidth(s)
-- to each side. Past that: a beach, then water. Every builder (road, gates,
-- lawns, props, trees, terrain, shore walls) asks this module, so they all
-- agree on where things are.
--
-- Points map to (s, d) through a raster of 4-stud cells built once at
-- require time by sweeping the road's normals (nearest road point wins).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MapLayout = require(Shared.Config.MapLayout)
local Zones = require(Shared.Config.Zones)

local MapGeometry = {}

local CELL = 4
local STEP = 1 -- road sample spacing (studs of s)
local ROAD = MapLayout.Road
MapGeometry.Cell = CELL

-- Areas in unlock order, with their stretch of road ----------------------------

export type Stretch = { Id: string, Def: MapLayout.AreaDef, Start: number, Finish: number, Index: number }

MapGeometry.Order = {} :: { [string]: number }
MapGeometry.Areas = {} :: { Stretch }
MapGeometry.ById = {} :: { [string]: Stretch }
do
	local s = 0
	for index, zone in Zones.List do
		MapGeometry.Order[zone.Id] = index
		local def = MapLayout.Areas[zone.Id]
		if def then
			local stretch = { Id = zone.Id, Def = def, Start = s, Finish = s + def.Length, Index = #MapGeometry.Areas + 1 }
			table.insert(MapGeometry.Areas, stretch)
			MapGeometry.ById[zone.Id] = stretch
			s += def.Length
		end
	end
	MapGeometry.LastAreaEnd = s
end
MapGeometry.LandStart = -ROAD.StartLand
MapGeometry.LandEnd = MapGeometry.LastAreaEnd + ROAD.EndLand
MapGeometry.RoadEnd = MapGeometry.LandEnd + ROAD.BridgeLength

-- The stretch an s falls in (before the road: the first area; past the last
-- area: the last one).
function MapGeometry.StretchAt(s: number): Stretch?
	local areas = MapGeometry.Areas
	for _, stretch in areas do
		if s < stretch.Finish then
			return stretch
		end
	end
	return areas[#areas]
end

-- Smooth noise along the road, so edges wobble instead of running straight.
-- `salt` picks an independent wave; result in [-amplitude, amplitude].
function MapGeometry.Wobble(s: number, salt: number, amplitude: number): number
	local phase = (MapLayout.Seed % 997) / 97 + salt * 2.39
	return amplitude * (0.55 * math.sin(s / 27 + phase) + 0.3 * math.sin(s / 11.7 + phase * 1.9) + 0.15 * math.sin(s / 5.3 + phase * 3.1))
end

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- How far the land reaches from the road center on one side (side = 1 or
-- -1). Widths blend between neighbouring areas so the shore never steps.
local BLEND = 30
function MapGeometry.HalfWidth(s: number, side: number): number
	local areas = MapGeometry.Areas
	local stretch = MapGeometry.StretchAt(s) :: Stretch
	local width = stretch.Def.HalfWidth
	local prev = areas[stretch.Index - 1]
	local nextArea = areas[stretch.Index + 1]
	if prev and s - stretch.Start < BLEND then
		local t = smoothstep(0.5 + (s - stretch.Start) / (2 * BLEND))
		width = prev.Def.HalfWidth + (width - prev.Def.HalfWidth) * t
	elseif nextArea and stretch.Finish - s < BLEND then
		local t = smoothstep(0.5 - (stretch.Finish - s) / (2 * BLEND))
		width = width + (nextArea.Def.HalfWidth - width) * t
	end
	width *= 1 + MapGeometry.Wobble(s, side * 3.7, 0.12)
	-- Round both ends of the island instead of cutting them square.
	local taper = math.min(width, 90)
	local fromEnd = math.max(s - (MapGeometry.LandEnd - taper), (MapGeometry.LandStart + taper) - s)
	if fromEnd > 0 then
		width *= math.sqrt(math.max(0, 1 - (fromEnd / taper) ^ 2))
	end
	return width
end

-- Signed distance from the land's edge (negative inside an area, 0..Beach
-- on the beach, beyond that water).
function MapGeometry.EdgeDistance(s: number, d: number): number
	local side = if d >= 0 then 1 else -1
	return math.max(math.abs(d) - MapGeometry.HalfWidth(s, side), s - MapGeometry.LandEnd, MapGeometry.LandStart - s)
end

-- The road's center line --------------------------------------------------------

local function catmullRom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: number): Vector2
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

local positions: { Vector3 } = {} -- road center at s = sMin + (i - 1) * STEP (y = 0)
local tangents: { Vector3 } = {}
local sMin = MapGeometry.LandStart - MapLayout.Beach - CELL
do
	-- Dense spline points, then resampled every STEP studs of arc length.
	local points = ROAD.Points
	local dense: { Vector2 } = {}
	for i = 1, #points - 1 do
		local p0 = points[math.max(i - 1, 1)]
		local p1, p2 = points[i], points[i + 1]
		local p3 = points[math.min(i + 2, #points)]
		for k = 0, 59 do
			table.insert(dense, catmullRom(p0, p1, p2, p3, k / 60))
		end
	end
	table.insert(dense, points[#points])

	local first = (dense[2] - dense[1]).Unit
	-- Before the road start: a straight extension backward (land behind the house).
	local back = math.ceil(-sMin / STEP)
	for i = back, 1, -1 do
		local p = dense[1] - first * i * STEP
		table.insert(positions, Vector3.new(p.X, 0, p.Y))
	end
	local travelled, nextS = 0, 0
	for i = 1, #dense - 1 do
		local a, b = dense[i], dense[i + 1]
		local length = (b - a).Magnitude
		while nextS <= travelled + length do
			local p = a:Lerp(b, (nextS - travelled) / length)
			table.insert(positions, Vector3.new(p.X, 0, p.Y))
			nextS += STEP
		end
		travelled += length
	end
	sMin = -back * STEP
	assert(travelled >= MapGeometry.RoadEnd + 10, "[MowIt][Map] MapLayout.Road.Points is shorter than the areas + EndLand + BridgeLength")
	for i = 1, #positions do
		local a = positions[math.max(i - 1, 1)]
		local b = positions[math.min(i + 1, #positions)]
		tangents[i] = (b - a).Unit
	end
end

local function sampleIndex(s: number): (number, number)
	local f = (s - sMin) / STEP + 1
	local i = math.clamp(math.floor(f), 1, #positions - 1)
	return i, math.clamp(f - i, 0, 1)
end

-- Ground point (y = 0) at road coordinates (s, d).
function MapGeometry.Point(s: number, d: number): Vector3
	local i, t = sampleIndex(s)
	local center = positions[i]:Lerp(positions[i + 1], t)
	local tangent = tangents[i]:Lerp(tangents[i + 1], t).Unit
	return center + tangent:Cross(Vector3.yAxis) * d
end

-- Frame on the road center at s: LookVector along the road (away from the
-- house), RightVector toward +d. Origin at y = 0.
function MapGeometry.Frame(s: number): CFrame
	local i, t = sampleIndex(s)
	local center = positions[i]:Lerp(positions[i + 1], t)
	local tangent = tangents[i]:Lerp(tangents[i + 1], t).Unit
	return CFrame.lookAt(center, center + tangent)
end

-- Road center points from s = a to s = b, every `step` studs.
function MapGeometry.RoadPoints(a: number, b: number, step: number): { Vector3 }
	local points = {}
	local s = a
	while s < b do
		table.insert(points, MapGeometry.Point(s, 0))
		s += step
	end
	table.insert(points, MapGeometry.Point(b, 0))
	return points
end

-- Raster: (ix, iz) cell -> nearest road coordinates ---------------------------------

type CellInfo = { S: number, D: number }
local raster: { [number]: { [number]: CellInfo } } = {}
do
	local beach = MapLayout.Beach
	local sMax = MapGeometry.LandEnd + beach + CELL
	local i = 1
	while i <= #positions do
		local s = sMin + (i - 1) * STEP
		if s > sMax then
			break
		end
		local center, right = positions[i], tangents[i]:Cross(Vector3.yAxis)
		for _, side in { 1, -1 } do
			local reach = MapGeometry.HalfWidth(s, side) + beach + CELL
			local d = 0
			while d <= reach do
				local p = center + right * (d * side)
				local ix, iz = math.floor(p.X / CELL), math.floor(p.Z / CELL)
				local column = raster[ix]
				if not column then
					column = {}
					raster[ix] = column
				end
				local info = column[iz]
				if not info or math.abs(info.D) > d then
					column[iz] = { S = s, D = d * side }
				end
				d += 2
			end
		end
		i += 1
	end
end

-- Road coordinates of a ground point, or nil far out in the water.
function MapGeometry.Locate(point: Vector3): (number?, number?)
	local column = raster[math.floor(point.X / CELL)]
	local info = column and column[math.floor(point.Z / CELL)]
	if not info then
		return nil, nil
	end
	return info.S, info.D
end

-- "land" (inside an area), "beach", or nil (water).
function MapGeometry.KindAt(point: Vector3): string?
	local s, d = MapGeometry.Locate(point)
	if not s then
		return nil
	end
	local edge = MapGeometry.EdgeDistance(s, d :: number)
	return if edge < 0 then "land" elseif edge < MapLayout.Beach then "beach" else nil
end

-- Which area a point is in, or nil (beach, water).
function MapGeometry.AreaAt(point: Vector3): string?
	local s, d = MapGeometry.Locate(point)
	if not s or MapGeometry.EdgeDistance(s, d :: number) >= 0 then
		return nil
	end
	local stretch = MapGeometry.StretchAt(s)
	return stretch and stretch.Id
end

-- True when the whole circle (approximated by 8 points) is inside `areaId`.
function MapGeometry.FitsIn(point: Vector3, clearance: number, areaId: string): boolean
	if MapGeometry.AreaAt(point) ~= areaId then
		return false
	end
	for k = 0, 7 do
		local a = k * math.pi / 4
		if MapGeometry.AreaAt(point + Vector3.new(math.cos(a), 0, math.sin(a)) * clearance) ~= areaId then
			return false
		end
	end
	return true
end

-- Every rastered cell: fn(ix, iz, center (y = 0), s, d).
function MapGeometry.ForEachCell(fn: (number, number, Vector3, number, number) -> ())
	for ix, column in raster do
		for iz, info in column do
			fn(ix, iz, Vector3.new(ix * CELL + CELL / 2, 0, iz * CELL + CELL / 2), info.S, info.D)
		end
	end
end

return MapGeometry
