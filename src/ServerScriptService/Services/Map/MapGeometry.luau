--!strict
-- The shape of the land, as pure math (no instances): which area a point
-- belongs to, and where the wobbly ring/sector borders run. Every builder
-- (fences, walls, lawns, props, paths) asks this module, so borders and
-- contents always agree. Data comes from Shared/Config/MapLayout.luau.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MapLayout = require(Shared.Config.MapLayout)
local Zones = require(Shared.Config.Zones)

local MapGeometry = {}

local TAU = math.pi * 2

-- Unit vector on the ground for an angle in degrees (0 = north = -Z,
-- clockwise toward +X).
function MapGeometry.Direction(angle: number): Vector3
	local a = math.rad(angle)
	return Vector3.new(math.sin(a), 0, -math.cos(a))
end

-- Angle in degrees (-180..180] and distance from the center.
function MapGeometry.Polar(point: Vector3): (number, number)
	return math.deg(math.atan2(point.X, -point.Z)), Vector3.new(point.X, 0, point.Z).Magnitude
end

function MapGeometry.Point(angle: number, radius: number): Vector3
	return MapGeometry.Direction(angle) * radius
end

-- Wobbly outer radius of a ring at an angle.
function MapGeometry.RingRadius(ring: number, angle: number): number
	local base = MapLayout.RingRadius[ring]
	local a = math.rad(angle)
	return base + MapLayout.RingWobble * (0.6 * math.sin(3 * a + ring * 1.7) + 0.4 * math.sin(7 * a + ring * 0.9))
end

-- Wobbly sector border: the angle of the border line `borderAngle` at a
-- given radius.
function MapGeometry.BorderAngle(borderAngle: number, radius: number): number
	return borderAngle + MapLayout.SectorWobble * math.sin(radius / 17 + math.rad(borderAngle) * 3)
end

local function angleBetween(angle: number, from: number, to: number): boolean
	local span = (to - from) % 360
	return (angle - from) % 360 < span
end

-- Areas grouped by ring, sorted by unlock order.
local byRing: { [number]: { { Id: string, Def: MapLayout.AreaDef } } } = {}
MapGeometry.Order = {} :: { [string]: number }
for index, zone in Zones.List do
	MapGeometry.Order[zone.Id] = index
	local def = MapLayout.Areas[zone.Id]
	if def then
		byRing[def.Ring] = byRing[def.Ring] or {}
		table.insert(byRing[def.Ring], { Id = zone.Id, Def = def })
	end
end

local maxRing = 0
for ring in MapLayout.RingRadius do
	maxRing = math.max(maxRing, ring)
end
MapGeometry.LastRing = maxRing

-- Which area a point is in, or nil outside the land (the forest).
function MapGeometry.AreaAt(point: Vector3): string?
	local angle, radius = MapGeometry.Polar(point)
	for ring = 0, maxRing do
		if radius < MapGeometry.RingRadius(ring, angle) then
			local areas = byRing[ring]
			if not areas then
				return nil
			end
			if ring == 0 then
				return areas[1].Id
			end
			for _, area in areas do
				local def = area.Def
				local from = MapGeometry.BorderAngle(def.From :: number, radius)
				local to = MapGeometry.BorderAngle(def.To :: number, radius)
				if angleBetween(angle, from, to) then
					return area.Id
				end
			end
			return nil
		end
	end
	return nil
end

-- True when the whole circle (approximated by 8 points) is inside `areaId`.
function MapGeometry.FitsIn(point: Vector3, clearance: number, areaId: string): boolean
	if MapGeometry.AreaAt(point) ~= areaId then
		return false
	end
	for i = 0, 7 do
		local a = i * TAU / 8
		if MapGeometry.AreaAt(point + Vector3.new(math.cos(a), 0, math.sin(a)) * clearance) ~= areaId then
			return false
		end
	end
	return true
end

-- Center of an area (where its stall and paths meet).
function MapGeometry.Hub(def: MapLayout.AreaDef): Vector3
	if def.Ring == 0 then
		return Vector3.zero
	end
	local from, to = def.From :: number, def.To :: number
	local mid = from + ((to - from) % 360) / 2
	local inner = MapLayout.RingRadius[def.Ring - 1]
	local outer = MapLayout.RingRadius[def.Ring]
	return MapGeometry.Point(mid, (inner + outer) / 2)
end

-- A random point that falls inside the area (rejection sampling).
function MapGeometry.RandomPointIn(areaId: string, def: MapLayout.AreaDef, rng: Random): Vector3?
	local inner = if def.Ring == 0 then 0 else MapLayout.RingRadius[def.Ring - 1]
	local outer = MapLayout.RingRadius[def.Ring]
	local from = def.From or -180
	local span = if def.Ring == 0 then 360 else ((def.To :: number) - from) % 360
	for _ = 1, 40 do
		local angle = from + rng:NextNumber() * span
		-- sqrt keeps points evenly spread over the area, not bunched inward
		local radius = math.sqrt(rng:NextNumber() * (outer * outer - inner * inner) + inner * inner)
		local point = MapGeometry.Point(angle, radius)
		if MapGeometry.AreaAt(point) == areaId then
			return point
		end
	end
	return nil
end

-- Border lines, each a polyline of ground points. Rings give full circles;
-- every outer-ring area contributes the radial line at its From angle
-- (sectors tile the ring, so each line exists exactly once).
function MapGeometry.BorderLines(): { { Vector3 } }
	local lines = {}
	local spacing = MapLayout.FencePostSpacing
	for ring = 0, maxRing do
		local points = {}
		local radius = MapLayout.RingRadius[ring]
		local count = math.max(12, math.round(TAU * radius / spacing))
		for i = 0, count do
			local angle = i * 360 / count
			table.insert(points, MapGeometry.Point(angle, MapGeometry.RingRadius(ring, angle)))
		end
		table.insert(lines, points)
	end
	for ring = 1, maxRing do
		for _, area in byRing[ring] or {} do
			local border = area.Def.From :: number
			local inner = MapGeometry.RingRadius(ring - 1, border)
			local outer = MapGeometry.RingRadius(ring, border)
			local points = {}
			local count = math.max(2, math.round((outer - inner) / spacing))
			for i = 0, count do
				local radius = inner + (outer - inner) * i / count
				table.insert(points, MapGeometry.Point(MapGeometry.BorderAngle(border, radius), radius))
			end
			table.insert(lines, points)
		end
	end
	return lines
end

-- World position of an area's gate, snapped onto the actual border.
function MapGeometry.GatePoint(def: MapLayout.AreaDef): Vector3?
	local gate = def.Gate
	if not gate then
		return nil
	end
	for ring, radius in MapLayout.RingRadius do
		if radius == gate.Radius then
			return MapGeometry.Point(gate.Angle, MapGeometry.RingRadius(ring, gate.Angle))
		end
	end
	return MapGeometry.Point(MapGeometry.BorderAngle(gate.Angle, gate.Radius), gate.Radius)
end

return MapGeometry
