--!strict
-- Saved plant timestamps survive offline. Cut mature plots at their real position.
local Shared = game:GetService("ReplicatedStorage").Shared
local Seeds = require(Shared.Config.Seeds)
local Zones = require(Shared.Config.Zones)
local Tuning = require(Shared.Config.Progression)
local GrassBag = require(Shared.GrassBag)
local Profiles = require(script.Parent.ProfileService)
local Land = require(script.Parent.LandService)
local Layout = require(Shared.PlantingPlots)
local PlotService = {}
local function areaOf(zoneId: string): BasePart?
	local zones = workspace:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild(zoneId)
	return Layout.LargestArea(zone)
end
function PlotService.Position(zoneId: string, slot: number): Vector3?
	local area = areaOf(zoneId)
	if not area then return nil end
	return Layout.Position(area, slot)
end
function PlotService.Plant(player: Player, id: string): string
	local profile = Profiles.Get(player)
	local seed = Seeds.ById[id]
	if not profile or not seed then return "Unknown seed." end
	if not Land.IsHost(player) then return "Plant seeds on your own land." end
	if not profile.UnlockedZoneIds[seed.Expansion] then return "Unlock that expansion first." end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return "Wait for your character." end
	local cost = Tuning.SeedPricePerZone * Zones.IndexById[seed.Expansion]
	if profile.Coins < cost then return "Not enough Coins for this seed." end
	for slot = 1, Tuning.PlotsPerZone do
		local key = seed.Expansion .. ":" .. slot
		local position = PlotService.Position(seed.Expansion, slot)
		if not profile.Plots[key] and position then
			if (root.Position - position).Magnitude > Tuning.PlotRadius * 3 then return "Walk to this expansion's planting beds first." end
			profile.Coins -= cost
			profile.Plots[key] = { SeedId = id, ReadyAt = os.time() + seed.GrowSeconds, ZoneId = seed.Expansion, Slot = slot }
			return "Seed planted. It keeps growing while you are away."
		end
	end
	return "Both planting beds are occupied. Cut mature grass to harvest."
end
function PlotService.CutNear(player: Player, position: Vector3, radius: number): number
	local profile = Profiles.Get(player)
	if not profile or not Land.IsHost(player) then return 0 end
	local gained = 0
	for key, plot in profile.Plots do
		local center = PlotService.Position(plot.ZoneId, plot.Slot)
		local seed = Seeds.ById[plot.SeedId]
		if seed and center and os.time() >= plot.ReadyAt and (center - position).Magnitude <= radius + Tuning.PlotRadius then
			local remaining = plot.Remaining or math.floor(Tuning.PlotYield * seed.YieldMultiplier)
			local stored = GrassBag.Add(profile, "golden", remaining)
			gained += stored
			plot.Remaining = remaining - stored
			if plot.Remaining <= 0 then profile.Plots[key] = nil end
		end
	end
	return gained
end
return PlotService
