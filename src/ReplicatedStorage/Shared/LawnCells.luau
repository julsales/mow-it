--!strict
-- Where the lawns are, read from the map's contract parts: every 4x4
-- terrain voxel column whose center lies inside a "GrassArea" part under
-- Workspace/Zones/<ZoneId> or on a personal base under Workspace/Bases
-- (built by MapService, or baked and hand-edited
-- in Studio). The lawn surface is the bottom of the part. The server
-- (GrassService) owns each player's cells; every client paints and draws
-- its own player's lawn (GrassState, GrassTufts).

local Workspace = game:GetService("Workspace")

local GameConfig = require(script.Parent.Config.GameConfig)
local Zones = require(script.Parent.Config.Zones)
local Bases = require(script.Parent.Bases)

local LawnCells = {}

LawnCells.Size = 4 -- Terrain voxel size: one lawn cell = one voxel column

export type Cell = { ZoneId: string, Center: Vector3, Ix: number, Iz: number }

function LawnCells.Key(ix: number, iz: number): string
	return ix .. "," .. iz
end

-- How a cell's ground looks: tall Grass while standing, and short lawn
-- when mowed, alternating light/dark every `STRIPE` cells so mowed lawns
-- show stripes.
LawnCells.Tall = Enum.Material.Grass
local STRIPE = GameConfig.GrassStripeCells or 2

function LawnCells.Mowed(ix: number): Enum.Material
	return if math.floor(ix / STRIPE) % 2 == 0 then Enum.Material.Ground else Enum.Material.Mud
end

-- The terrain region of the cell whose lawn surface is centered on `center`.
function LawnCells.Region(center: Vector3): Region3
	local half = Vector3.new(LawnCells.Size / 2, 4, LawnCells.Size / 2)
	return Region3.new(center - half, center + half):ExpandToGrid(LawnCells.Size)
end

-- Grid coordinates of the cell under a point.
function LawnCells.Index(point: Vector3): (number, number)
	return math.floor(point.X / LawnCells.Size), math.floor(point.Z / LawnCells.Size)
end

-- The lawn cells inside one GrassArea part (skips keys already in `seen`).
function LawnCells.InPart(part: BasePart, zoneId: string, seen: { [string]: boolean }, out: { Cell })
	local size = LawnCells.Size
	local cf, partSize = part.CFrame, part.Size
	local half = partSize / 2
	local reach = Vector3.new(partSize.X, 0, partSize.Z).Magnitude / 2
	local y = cf.Position.Y - half.Y
	for ix = math.floor((cf.X - reach) / size), math.floor((cf.X + reach) / size) do
		for iz = math.floor((cf.Z - reach) / size), math.floor((cf.Z + reach) / size) do
			local center = Vector3.new(ix * size + size / 2, y, iz * size + size / 2)
			local p = cf:PointToObjectSpace(Vector3.new(center.X, cf.Y, center.Z))
			local k = LawnCells.Key(ix, iz)
			if math.abs(p.X) <= half.X and math.abs(p.Z) <= half.Z and not seen[k] then
				seen[k] = true
				table.insert(out, { ZoneId = zoneId, Center = center, Ix = ix, Iz = iz })
			end
		end
	end
end

-- The zone a GrassArea belongs to: its island (Workspace/Zones/<ZoneId>),
-- or the home zone for the little lawns on personal bases
-- (Workspace/Bases); nil anywhere else.
function LawnCells.ZoneOf(part: Instance): string?
	local zones = Workspace:FindFirstChild("Zones")
	local bases = Bases.Folder()
	local node = part.Parent
	while node and node.Parent ~= zones and node.Parent ~= bases do
		node = node.Parent
	end
	if not node or not node.Parent then
		return nil
	end
	return if node.Parent == zones then node.Name else Zones.List[1].Id
end

-- The folders lawns can be in.
function LawnCells.Roots(): { Instance }
	local roots = {}
	local zones = Workspace:FindFirstChild("Zones")
	if zones then
		table.insert(roots, zones)
	end
	local bases = Bases.Folder()
	if bases then
		table.insert(roots, bases)
	end
	return roots
end

-- Every lawn cell, once each (overlapping GrassAreas count once).
function LawnCells.Collect(): { Cell }
	local result: { Cell } = {}
	local seen: { [string]: boolean } = {}
	for _, root in LawnCells.Roots() do
		for _, part in root:GetDescendants() do
			if part.Name == "GrassArea" and part:IsA("BasePart") then
				local zoneId = LawnCells.ZoneOf(part)
				if zoneId then
					LawnCells.InPart(part, zoneId, seen, result)
				end
			end
		end
	end
	return result
end

return LawnCells
