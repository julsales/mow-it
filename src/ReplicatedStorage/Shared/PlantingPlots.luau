--!strict
-- Shared world contracts for planting and station placement on organic lawns.
local Tuning = require(script.Parent.Config.Progression)
local PlantingPlots = {}
function PlantingPlots.LargestArea(zone: Instance?): BasePart?
	local area: BasePart? = nil
	if zone then
		for _, candidate in zone:GetDescendants() do
			if candidate:IsA("BasePart") and candidate.Name == "GrassArea" and (not area or candidate.Size.X * candidate.Size.Z > area.Size.X * area.Size.Z or (candidate.Size.X * candidate.Size.Z == area.Size.X * area.Size.Z and (candidate.Position.X < area.Position.X or (candidate.Position.X == area.Position.X and candidate.Position.Z < area.Position.Z)))) then
				area = candidate
			end
		end
	end
	return area
end
function PlantingPlots.Contains(zone: Instance?, position: Vector3): boolean
	if not zone then return false end
	for _, area in zone:GetDescendants() do
		if area:IsA("BasePart") and area.Name == "GrassArea" then
			local point = area.CFrame:PointToObjectSpace(position)
			if math.abs(point.X) <= area.Size.X / 2 and math.abs(point.Z) <= area.Size.Z / 2 and math.abs(point.Y) <= Tuning.PlotRadius then return true end
		end
	end
	return false
end
function PlantingPlots.Position(area: BasePart, slot: number): Vector3
	local room = math.max(0, area.Size.X / 2 - Tuning.PlotSize / 2)
	return area.CFrame:PointToWorldSpace(Vector3.new(
		math.clamp((slot - (Tuning.PlotsPerZone + 1) / 2) * Tuning.PlotRadius * 2, -room, room),
		-area.Size.Y / 2, 0
	))
end
return PlantingPlots
