--!strict
-- Where the lawns are, read from the map's contract parts: every 4x4
-- terrain voxel column whose center lies inside a "GrassArea" part under
-- Workspace/Zones/<ZoneId> (built by MapService, or baked and hand-edited
-- in Studio). The lawn surface is the bottom of the part. The server
-- (GrassService) owns the cells' state; clients (GrassTufts) draw them.

local LawnCells = {}

LawnCells.Size = 4 -- Terrain voxel size: one lawn cell = one voxel column

export type Cell = { ZoneId: string, Center: Vector3, Ix: number, Iz: number }

function LawnCells.Key(ix: number, iz: number): string
	return ix .. "," .. iz
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

-- The zone a GrassArea belongs to (Zones/<ZoneId>/...), or nil.
function LawnCells.ZoneOf(part: Instance, zones: Instance): string?
	local node = part.Parent
	while node and node.Parent ~= zones do
		node = node.Parent
	end
	return node and node.Name
end

-- Every lawn cell, once each (overlapping GrassAreas count once).
function LawnCells.Collect(zones: Instance?): { Cell }
	local result: { Cell } = {}
	if not zones then
		return result
	end
	local seen: { [string]: boolean } = {}
	for _, zoneFolder in zones:GetChildren() do
		for _, part in zoneFolder:GetDescendants() do
			if part.Name == "GrassArea" and part:IsA("BasePart") then
				LawnCells.InPart(part, zoneFolder.Name, seen, result)
			end
		end
	end
	return result
end

return LawnCells
