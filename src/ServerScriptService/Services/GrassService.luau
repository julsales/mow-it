--!strict
-- Grass tufts: the server owns every tuft. A tuft is a small anchored Part
-- tagged "GrassTuft" with attributes ZoneId + Health. Builders may replace
-- the look later (mesh/ decal from docs/ASSETS.md) — gameplay only cares
-- about position, zone and health, so art swaps never touch this code.
--
-- Map contract (built in Studio, see docs/ARCHITECTURE.md):
--   Workspace/Zones/<ZoneId>/GrassArea  (a Part marking where tufts grow)
-- If a zone has no GrassArea yet, GrayboxService creates one, so a fresh
-- place is playable before any map building happens.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)
local GameConfig = require(Shared.Config.GameConfig)

local GrassService = {}

local tuftsByZone: { [string]: { BasePart } } = {}

local function makeTuft(zoneDef, area: BasePart): BasePart
	local tuft = Instance.new("Part")
	tuft.Name = "GrassTuft"
	tuft.Anchored = true
	tuft.CanCollide = false
	tuft.CanQuery = false -- cutting is math on the server, not raycasts
	tuft.Size = Vector3.new(1.6, 1.2, 1.6)
	tuft.Color = zoneDef.ThemeColor
	tuft.Material = Enum.Material.Grass
	local half = area.Size / 2
	tuft.Position = area.Position
		+ Vector3.new((math.random() * 2 - 1) * (half.X - 1), half.Y + 0.6, (math.random() * 2 - 1) * (half.Z - 1))
	tuft:SetAttribute("ZoneId", zoneDef.Id)
	tuft:SetAttribute("Health", zoneDef.GrassHealth)
	tuft.Parent = Workspace:FindFirstChild("GrassTufts") or Workspace
	CollectionService:AddTag(tuft, "GrassTuft")
	return tuft
end

function GrassService.GetTuftsInRadius(position: Vector3, radius: number): { BasePart }
	local found = {}
	for _, list in tuftsByZone do
		for _, tuft in list do
			if tuft.Parent and (tuft.Position - position).Magnitude <= radius then
				table.insert(found, tuft)
			end
		end
	end
	return found
end

-- Removes a tuft and schedules its regrowth. Returns the zone it was in.
function GrassService.Harvest(tuft: BasePart): string?
	local zoneId = tuft:GetAttribute("ZoneId") :: string?
	if not zoneId then
		return nil
	end
	local list = tuftsByZone[zoneId]
	if list then
		local index = table.find(list, tuft)
		if index then
			table.remove(list, index)
		end
	end
	tuft:Destroy()
	task.delay(GameConfig.GrassRespawnSeconds, function()
		GrassService.SpawnOne(zoneId)
	end)
	return zoneId
end

function GrassService.SpawnOne(zoneId: string)
	local zoneDef = Zones.ById[zoneId]
	local zonesFolder = Workspace:FindFirstChild("Zones")
	local zoneFolder = zonesFolder and zonesFolder:FindFirstChild(zoneId)
	local area = zoneFolder and zoneFolder:FindFirstChild("GrassArea") :: BasePart?
	if not zoneDef or not area then
		return
	end
	tuftsByZone[zoneId] = tuftsByZone[zoneId] or {}
	table.insert(tuftsByZone[zoneId], makeTuft(zoneDef, area))
end

function GrassService.Init()
	local container = Instance.new("Folder")
	container.Name = "GrassTufts"
	container.Parent = Workspace
	for _, zoneDef in Zones.List do
		tuftsByZone[zoneDef.Id] = {}
		for _ = 1, zoneDef.TuftCount do
			GrassService.SpawnOne(zoneDef.Id)
		end
	end
end

return GrassService
