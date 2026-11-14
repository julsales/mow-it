--!strict
-- Builds the personal bases (Shared/Config/Bases.luau): one small island
-- per row of `Headings`, in a fan around the home island, each with a
-- bridge to it, a cabin, a hay yard, a jetty with a boat, a name board and
-- the spot its owner spawns on.
--
-- Contract (Shared/Bases.luau, docs/EDITING.md): Workspace/Bases/Base<N>
-- is one Model per base holding the Models "Bridge", "PlayerBase" (the
-- cabin), "HayYard", "Jetty", "Path", "Trees", "ShoreWalls", the folder
-- "Lawns" (GrassArea parts), the SpawnLocation "BaseSpawn", the board
-- "OwnerSign" and the invisible "OwnerTag" the owner's picture floats on. Like the islands,
-- a base can be dragged by hand: its `BakedPivot` attribute tells
-- MapService.Restamp how far it moved, so the ground follows.
--
-- The generic builders (bridge deck, dirt path, dock, terrain surface)
-- belong to MapService, which hands them in as a `Kit`, so islands and
-- bases are made by the same code.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Bases)
local MapLayout = require(Shared.Config.MapLayout)
local SharedBases = require(Shared.Bases)

local Props = require(script.Parent.Props)
local ShopInterior = require(script.Parent.ShopInterior)
local HayYard = require(script.Parent.HayYard)
local Geo = require(script.Parent.MapGeometry)

local Bases = {}

export type Kit = {
	-- A wooden deck with rails from a to b (points at y = 0), `width` wide.
	BridgeDeck: (parent: Instance, a: Vector3, b: Vector3, width: number?) -> (),
	-- Invisible walls along both sides of a lane from a to b.
	Corridor: (parent: Instance, a: Vector3, b: Vector3, width: number) -> (),
	-- A smooth curve through the points, for Path.
	Spline: (points: { Vector3 }) -> { Vector3 },
	-- A dirt path through the points.
	Path: (parent: Instance, points: { Vector3 }, width: number) -> (),
	-- A jetty with a moored boat leaving the coast at `coast` toward `dir`;
	-- its deck starts `inland` studs in from the coast.
	Dock: (parent: Instance, coast: Vector3, dir: Vector3, length: number, inland: number) -> Model,
	-- An invisible spawn pad.
	Spawn: (at: CFrame, parent: Instance, name: string) -> SpawnLocation,
	-- Surface height and material `edge` studs from a coast (negative inland).
	SurfaceAt: (edge: number, cliff: number, beach: number?) -> (number, Enum.Material),
	WaterTop: number, -- top of the water fill
	Bottom: number, -- bottom of every ground column
	SurfaceLift: number,
}

export type Slot = {
	Index: number,
	Name: string,
	Heading: number,
	Out: Vector3, -- unit vector away from the home island
	Center: Vector3, -- y = 0
	Frame: CFrame, -- on the ground at the center, +Z toward the home island
	BridgeStart: Vector3, -- on the home island's coast
	BridgeEnd: Vector3, -- on the base's coast
}

local CELL = 4
local GROUND_TOP = Props.GroundTop
local STAMP_REACH = 30 -- how far past the coast the sea floor is shaped

-- Geometry -----------------------------------------------------------------------

Bases.Slots = {} :: { Slot }
do
	local home = Geo.Islands[1]
	for index, heading in Config.Headings do
		local out = Geo.Direction(heading)
		local coast = Geo.CoastRadius(home, heading)
		local start = home.Center + out * coast
		local finish = start + out * Config.Gap
		local center = finish + out * (Config.Depth / 2)
		local ground = Vector3.new(center.X, GROUND_TOP, center.Z)
		table.insert(Bases.Slots, {
			Index = index,
			Name = "Base" .. index,
			Heading = heading,
			Out = out,
			Center = center,
			Frame = CFrame.lookAt(ground, ground + out),
			BridgeStart = start,
			BridgeEnd = finish,
		})
	end
end

-- The island is a superellipse that narrows toward the home island:
-- half its width at `z` studs in front of its center (base frame).
local function halfWidth(z: number): number
	local toward = math.clamp(z / (Config.Depth / 2), 0, 1.5)
	return Config.Width / 2 * (1 - Config.Taper * toward)
end

-- > 1 outside the coast, < 1 inside (base-frame point).
local function shape(x: number, z: number): number
	local n = Config.Roundness
	return ((math.abs(x) / halfWidth(z)) ^ n + (math.abs(z) / (Config.Depth / 2)) ^ n) ^ (1 / n)
end

-- Signed distance from a base's coast (negative inland), measured along
-- the line from its center.
function Bases.EdgeDistance(slot: Slot, point: Vector3): number
	local p = slot.Frame:PointToObjectSpace(Vector3.new(point.X, GROUND_TOP, point.Z))
	local r = math.sqrt(p.X * p.X + p.Z * p.Z)
	if r < 0.01 then
		return -math.min(Config.Width, Config.Depth) / 2
	end
	return r * (1 - 1 / shape(p.X, p.Z))
end

-- The point on a base's coast in a direction of its own frame (degrees,
-- 0 = toward the home island, clockwise seen from above), pushed `offset`
-- studs out.
local function coastPoint(slot: Slot, angle: number, offset: number): Vector3
	local rad = math.rad(angle)
	local x, z = math.sin(rad), math.cos(rad)
	local low, high = 0, math.max(Config.Width, Config.Depth)
	for _ = 1, 24 do
		local mid = (low + high) / 2
		if shape(x * mid, z * mid) < 1 then
			low = mid
		else
			high = mid
		end
	end
	local world = slot.Frame * Vector3.new(x * (low + offset), 0, z * (low + offset))
	return Vector3.new(world.X, 0, world.Z)
end

-- A ground frame in the base (base-frame offset; +Z keeps facing the home island).
local function inBase(slot: Slot, offset: CFrame): CFrame
	return slot.Frame * offset
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Where the jetty leaves the coast, and its direction.
local function jettyLine(slot: Slot): (Vector3, Vector3)
	local side = (slot.Frame * CFrame.new(Config.Jetty.Side, 0, 0)).Position
	return flat(side) + slot.Out * (Config.Depth / 2 - 1), slot.Out
end

-- The openings in shore walls and the lanes sea rocks must keep out of:
-- every base's bridge (both ends) and jetty.
function Bases.Openings(): { { Point: Vector3, Direction: Vector3 } }
	local openings = {}
	for _, slot in Bases.Slots do
		table.insert(openings, { Point = slot.BridgeStart, Direction = slot.Out })
		table.insert(openings, { Point = slot.BridgeEnd, Direction = slot.Out })
		local coast, dir = jettyLine(slot)
		table.insert(openings, { Point = coast, Direction = dir })
	end
	return openings
end

-- True when a point is on, or within `margin` studs of, a base or its bridge.
function Bases.Near(point: Vector3, margin: number): boolean
	for _, slot in Bases.Slots do
		if Bases.EdgeDistance(slot, point) < margin then
			return true
		end
		local rel = flat(point) - slot.BridgeStart
		local along = math.clamp(rel:Dot(slot.Out), 0, Config.Gap)
		if (rel - slot.Out * along).Magnitude < margin then
			return true
		end
	end
	return false
end

-- Terrain ------------------------------------------------------------------------

-- The ground of every base. `moved[name]` = how far that base's Model was
-- moved since it was built. Each column is cleared first (air above the
-- sea level, water below), so this also works on top of existing terrain.
function Bases.Stamp(kit: Kit, moved: { [string]: CFrame })
	local terrain = Workspace.Terrain
	local filled = 0
	for _, slot in Bases.Slots do
		local delta = moved[slot.Name] or CFrame.identity
		local back = delta:Inverse()
		local c = delta * slot.Center
		local reach = math.max(Config.Width, Config.Depth) / 2 + STAMP_REACH
		for ix = math.floor((c.X - reach) / CELL), math.floor((c.X + reach) / CELL) do
			for iz = math.floor((c.Z - reach) / CELL), math.floor((c.Z + reach) / CELL) do
				local center = Vector3.new(ix * CELL + CELL / 2, 0, iz * CELL + CELL / 2)
				local edge = Bases.EdgeDistance(slot, back * center)
				local _, islandEdge = Geo.Nearest(center)
				if edge > STAMP_REACH or islandEdge < edge then
					continue
				end
				local top, material = kit.SurfaceAt(edge, 0, Config.Beach)
				top += delta.Position.Y
				local seaHeight = kit.WaterTop - kit.Bottom
				-- Air first, over the whole column (water does not replace
				-- ground that is already there), then water, then the ground.
				terrain:FillBlock(CFrame.new(center.X, kit.Bottom + 28, center.Z), Vector3.new(CELL, 56, CELL), Enum.Material.Air)
				terrain:FillBlock(CFrame.new(center.X, kit.Bottom + seaHeight / 2, center.Z), Vector3.new(CELL, seaHeight, CELL), Enum.Material.Water)
				local height = top - kit.SurfaceLift - kit.Bottom
				if height > 0 then
					terrain:FillBlock(CFrame.new(center.X, kit.Bottom + height / 2, center.Z), Vector3.new(CELL, height, CELL), material)
				end
				filled += 1
				if filled % 300 == 0 then
					task.wait()
				end
			end
		end
	end
end

-- How far each base Model was moved since it was built (for Stamp).
function Bases.Moved(): { [string]: CFrame }
	local moved = {}
	for _, base in SharedBases.All() do
		local baked = base:GetAttribute("BakedPivot")
		if typeof(baked) == "CFrame" then
			moved[base.Name] = base:GetPivot() * baked:Inverse()
		end
	end
	return moved
end

-- Pieces -------------------------------------------------------------------------

-- Invisible walls just offshore, open at the bridge and at the jetty.
local function buildShoreWalls(base: Model, slot: Slot)
	local walls = Props.model("ShoreWalls", base)
	local height = MapLayout.ShoreWallHeight + MapLayout.WaterDepth
	local jettyCoast, jettyDir = jettyLine(slot)
	local lanes = {
		{ Point = slot.BridgeEnd, Direction = slot.Out, Half = Config.Bridge.Width / 2 + 1 },
		{ Point = jettyCoast, Direction = jettyDir, Half = MapLayout.Bridge.Width / 2 + 3 },
	}
	local count = 40
	for i = 0, count - 1 do
		local p = coastPoint(slot, i * 360 / count, MapLayout.ShoreWallOffset)
		local q = coastPoint(slot, (i + 1) * 360 / count, MapLayout.ShoreWallOffset)
		local mid = (p + q) / 2
		local open = false
		for _, lane in lanes do
			local rel = mid - lane.Point
			local across = math.abs(rel:Dot(lane.Direction:Cross(Vector3.yAxis)))
			if across < lane.Half and math.abs(rel:Dot(lane.Direction)) < 24 then
				open = true
			end
		end
		if not open then
			local wall = Props.make("ShoreWall", walls, {
				Size = Vector3.new(1, height, (q - p).Magnitude + 0.6),
				CFrame = CFrame.lookAt(mid, q) + Vector3.new(0, -MapLayout.WaterDepth + height / 2, 0),
				Color = Props.Colors.Water,
				Transparency = 1,
			})
			wall.CastShadow = false
			wall.CanQuery = false
		end
	end
end

-- The name board by the bridge: BaseService writes the owner on it.
local function buildSign(base: Model, slot: Slot)
	local spec = Config.Sign
	local cf = inBase(slot, CFrame.new(spec.At))
	local m = Props.model("OwnerBoard", base)
	local board = Props.make("OwnerSign", m, {
		Size = spec.Size,
		CFrame = cf * CFrame.new(0, spec.Height, 0),
		Color = Color3.fromRGB(110, 72, 42),
		Material = Enum.Material.WoodPlanks,
	})
	Props.label(board, Enum.NormalId.Back, Config.VacantText, Color3.fromRGB(255, 196, 90))
	for _, dx in { -spec.Size.X / 2 + 0.6, spec.Size.X / 2 - 0.6 } do
		Props.make("Post", m, {
			Size = Vector3.new(0.5, spec.Height + spec.Size.Y / 2, 0.5),
			CFrame = cf * CFrame.new(dx, (spec.Height + spec.Size.Y / 2) / 2, -0.45),
			Color = Props.Colors.DarkWood,
			Material = Enum.Material.Wood,
		})
	end
	m.WorldPivot = cf
end

local function buildBase(kit: Kit, parent: Instance, slot: Slot): Model
	local base = Props.model(slot.Name, parent)
	base.WorldPivot = slot.Frame
	base:SetAttribute("BakedPivot", slot.Frame)
	base:SetAttribute("Slot", slot.Index)
	base:SetAttribute(SharedBases.OwnerAttribute, 0)
	base:SetAttribute(SharedBases.OwnerNameAttribute, "")

	-- Bridge from the top of the home island's beach to the top of this one's.
	local bridge = Props.model("Bridge", base)
	local a = slot.BridgeStart - slot.Out * Config.Bridge.HomeInland
	local b = slot.BridgeEnd + slot.Out * Config.Bridge.Inland
	kit.BridgeDeck(bridge, a, b, Config.Bridge.Width)
	kit.Corridor(bridge, slot.BridgeStart - slot.Out * 6, slot.BridgeEnd + slot.Out * 4, Config.Bridge.Width)
	bridge.WorldPivot = CFrame.lookAt((a + b) / 2 + Vector3.new(0, GROUND_TOP, 0), b + Vector3.new(0, GROUND_TOP, 0))

	-- Cabin (the home cabin, smaller) and the walkway to its steps.
	local cabinAt = inBase(slot, Config.Cabin.Offset)
	local cabin = ShopInterior.BuildHome(base, cabinAt, Config.Cabin.Title)
	cabin.WorldPivot = cabinAt
	if math.abs(Config.Cabin.Scale - 1) > 0.01 then
		cabin:ScaleTo(Config.Cabin.Scale)
	end
	local entrance = cabin:GetAttribute("Entrance") :: Vector3?
	local steps = if entrance then flat(cabinAt.Position + (entrance - cabinAt.Position) * Config.Cabin.Scale) else flat(cabinAt.Position) - slot.Out * 12
	local path = Props.model("Path", base)
	local route = { b }
	for _, via in Config.Walkway.Via do
		table.insert(route, flat(inBase(slot, CFrame.new(via)).Position))
	end
	table.insert(route, steps)
	kit.Path(path, kit.Spline(route), Config.Walkway.Width)

	-- Hay yard. Its customers arrive at the jetty.
	local yard = HayYard.Build(base, inBase(slot, Config.Yard.Offset))
	local jettyCoast, jettyDir = jettyLine(slot)
	local jetty = kit.Dock(base, jettyCoast, jettyDir, Config.Jetty.Length, Config.Jetty.Inland)
	jetty.Name = "Jetty"
	local customerSpawn = yard and yard:FindFirstChild("CustomerSpawn")
	if customerSpawn and customerSpawn:IsA("BasePart") then
		-- They step off the boat at the land end of the jetty: a short walk.
		local at = jettyCoast - jettyDir * (Config.Jetty.Inland - 3)
		customerSpawn.CFrame = CFrame.new(at.X, GROUND_TOP + 1, at.Z)
	end

	local spawnAt = inBase(slot, CFrame.new(Config.Spawn))
	kit.Spawn(CFrame.lookAt(spawnAt.Position, spawnAt.Position + slot.Out), base, "BaseSpawn")
	buildSign(base, slot)
	-- Where the owner's picture and name float (BaseService fills it in).
	local tag = Props.make("OwnerTag", base, { Size = Vector3.one, CFrame = inBase(slot, CFrame.new(Config.Tag.At)), Color = Props.Colors.White, Transparency = 1, Solid = false })
	tag.Locked = false

	-- The base's own little lawn (the home island's grass).
	local lawns = Instance.new("Folder")
	lawns.Name = "Lawns"
	for _, spec in Config.Lawns do
		local area = Props.make("GrassArea", lawns, {
			Size = Vector3.new(spec.Size.X, 0.2, spec.Size.Z),
			CFrame = inBase(slot, CFrame.new(spec.Center.X, 0.1, spec.Center.Z)),
			Color = Color3.fromRGB(92, 168, 60),
			Transparency = 1,
			Solid = false,
		})
		area.Locked = false
	end
	lawns.Parent = base

	local trees = Props.model("Trees", base)
	for _, spot in Config.Trees do
		-- On the ground where they stand (the rim slopes down to the beach).
		local at = inBase(slot, CFrame.new(spot.At))
		local y = kit.SurfaceAt(Bases.EdgeDistance(slot, at.Position), 0, Config.Beach)
		Props.place(spot.Kind, trees, (at + Vector3.new(0, y - at.Y - 0.2, 0)) * CFrame.Angles(0, slot.Index * 1.7 + spot.At.X, 0), spot.Scale)
	end
	buildShoreWalls(base, slot)
	return base
end

-- Builds every base that is missing (never touches one that exists), and
-- returns the ones it built.
function Bases.Build(kit: Kit): { Model }
	local folder = SharedBases.Folder()
	if not folder then
		local f = Instance.new("Folder")
		f.Name = SharedBases.FolderName
		f.Parent = Workspace
		folder = f
	end
	local built = {}
	for _, slot in Bases.Slots do
		if not (folder :: Instance):FindFirstChild(slot.Name) then
			table.insert(built, buildBase(kit, folder :: Instance, slot))
			task.wait()
		end
	end
	return built
end

return Bases
