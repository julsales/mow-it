--!strict
-- The shape of the land, as pure math (no instances). One island per area
-- (Shared/Config/MapLayout.luau): a center, and a coast whose radius
-- wobbles with the angle. Each island after the first is joined to the
-- previous one by a straight bridge. Every builder (terrain, lawns, paths,
-- props, bridges, walls) asks this module, so they all agree on where the
-- coast is.
--
-- Angles are degrees clockwise from north (-Z); points live on y = 0.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MapLayout = require(Shared.Config.MapLayout)
local Zones = require(Shared.Config.Zones)

local MapGeometry = {}

-- Unit vector on the ground for an angle in degrees.
function MapGeometry.Direction(angle: number): Vector3
	local a = math.rad(angle)
	return Vector3.new(math.sin(a), 0, -math.cos(a))
end

-- Angle (degrees) of a ground vector.
function MapGeometry.AngleOf(v: Vector3): number
	return math.deg(math.atan2(v.X, -v.Z))
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Islands in unlock order --------------------------------------------------------

export type Island = {
	Id: string,
	Def: MapLayout.AreaDef,
	Index: number,
	Center: Vector3,
	Phases: { number }, -- coast wobble phases (from the seed)
}

MapGeometry.Order = {} :: { [string]: number }
MapGeometry.Islands = {} :: { Island }
MapGeometry.ById = {} :: { [string]: Island }

local function coastRadius(island: Island, angle: number): number
	local a = math.rad(angle)
	local p = island.Phases
	local wobble = 0.11 * math.sin(3 * a + p[1]) + 0.07 * math.sin(5 * a + p[2]) + 0.04 * math.sin(9 * a + p[3])
	return island.Def.Radius * (1 + wobble)
end

do
	local rng = Random.new(MapLayout.Seed)
	local previous: Island? = nil
	for index, zone in Zones.List do
		MapGeometry.Order[zone.Id] = index
		local def = MapLayout.Areas[zone.Id]
		if not def then
			continue
		end
		local island: Island = {
			Id = zone.Id,
			Def = def,
			Index = #MapGeometry.Islands + 1,
			Center = Vector3.zero,
			Phases = { rng:NextNumber() * 6.28, rng:NextNumber() * 6.28, rng:NextNumber() * 6.28 },
		}
		if previous then
			-- Place it so the coasts are `Gap` apart along the heading.
			local dir = MapGeometry.Direction(def.Heading)
			local out = coastRadius(previous, def.Heading)
			island.Center = previous.Center + dir * out -- temporary, for its own radius
			local back = coastRadius(island, def.Heading + 180)
			island.Center = previous.Center + dir * (out + def.Gap + back)
		end
		table.insert(MapGeometry.Islands, island)
		MapGeometry.ById[zone.Id] = island
		previous = island
	end
end

-- Coast radius of an island in a direction (degrees).
MapGeometry.CoastRadius = coastRadius

-- Signed distance from an island's coast (negative inland), approximated
-- radially. Good enough for shapes this round.
function MapGeometry.EdgeDistance(island: Island, point: Vector3): number
	local v = flat(point) - island.Center
	if v.Magnitude < 0.01 then
		return -coastRadius(island, 0)
	end
	return v.Magnitude - coastRadius(island, MapGeometry.AngleOf(v))
end

-- The island whose coast is nearest (smallest edge distance), and that distance.
function MapGeometry.Nearest(point: Vector3): (Island, number)
	local best, bestEdge = MapGeometry.Islands[1], math.huge
	for _, island in MapGeometry.Islands do
		local edge = MapGeometry.EdgeDistance(island, point)
		if edge < bestEdge then
			best, bestEdge = island, edge
		end
	end
	return best, bestEdge
end

-- Which area a point is on (land or beach), or nil in the water.
function MapGeometry.AreaAt(point: Vector3): string?
	local island, edge = MapGeometry.Nearest(point)
	return if edge < 0 then island.Id else nil
end

-- True when a circle around the point stays on the island, `margin` studs
-- inland from the coast.
function MapGeometry.FitsIn(point: Vector3, clearance: number, areaId: string, margin: number?): boolean
	local island = MapGeometry.ById[areaId]
	return island ~= nil and MapGeometry.EdgeDistance(island, point) < -(clearance + (margin or 0))
end

-- A random point on an island, at least `margin` studs inland.
function MapGeometry.RandomPointOn(island: Island, margin: number, rng: Random): Vector3?
	for _ = 1, 40 do
		local angle = rng:NextNumber() * 360
		local r = math.sqrt(rng:NextNumber()) * (coastRadius(island, angle) - margin)
		if r > 0 then
			return island.Center + MapGeometry.Direction(angle) * r
		end
	end
	return nil
end

-- Bridges ---------------------------------------------------------------------------

export type Bridge = {
	From: Island,
	To: Island,
	Start: Vector3, -- on the coast of From
	Finish: Vector3, -- on the coast of To
	Direction: Vector3, -- From -> To
	Gate: Vector3, -- middle of the bridge, where To's gate stands
}

-- The bridge that leads onto an island (nil for the first one).
function MapGeometry.BridgeTo(island: Island): Bridge?
	local from = MapGeometry.Islands[island.Index - 1]
	if not from then
		return nil
	end
	local dir = (island.Center - from.Center).Unit
	local angle = MapGeometry.AngleOf(dir)
	local start = from.Center + dir * coastRadius(from, angle)
	local finish = island.Center - dir * coastRadius(island, angle + 180)
	return {
		From = from,
		To = island,
		Start = start,
		Finish = finish,
		Direction = dir,
		Gate = (start + finish) / 2,
	}
end

-- Where a player steps off the bridge onto an island: the top of the beach
-- (for the first island, the side facing the next one).
function MapGeometry.Arrival(island: Island): (Vector3, Vector3)
	local bridge = MapGeometry.BridgeTo(island)
	if bridge then
		return bridge.Finish + bridge.Direction * MapLayout.Beach, bridge.Direction
	end
	local nextIsland = MapGeometry.Islands[island.Index + 1]
	local dir = if nextIsland then (island.Center - nextIsland.Center).Unit else Vector3.new(0, 0, 1)
	return island.Center - dir * 0, -dir
end

-- Where the path leaves an island toward the next bridge (nil on the last).
function MapGeometry.Departure(island: Island): Vector3?
	local nextIsland = MapGeometry.Islands[island.Index + 1]
	local bridge = nextIsland and MapGeometry.BridgeTo(nextIsland)
	return bridge and bridge.Start - bridge.Direction * MapLayout.Beach
end

-- Smooth noise around an island's coast in [0, 1] (cliff placement).
function MapGeometry.CoastNoise(island: Island, angle: number, salt: number): number
	local a = math.rad(angle)
	local p = island.Phases
	local v = 0.6 * math.sin(2 * a + p[2] * salt) + 0.4 * math.sin(5 * a + p[3] + salt)
	return (v + 1) / 2
end

-- Bounding box of all islands (min, max on the ground).
function MapGeometry.Bounds(): (Vector3, Vector3)
	local minV, maxV = Vector3.new(math.huge, 0, math.huge), Vector3.new(-math.huge, 0, -math.huge)
	for _, island in MapGeometry.Islands do
		local r = island.Def.Radius * 1.3
		minV = minV:Min(island.Center - Vector3.new(r, 0, r))
		maxV = maxV:Max(island.Center + Vector3.new(r, 0, r))
	end
	return minV, maxV
end

return MapGeometry
