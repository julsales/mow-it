--!strict
-- The core loop, server side: Cut -> carry Grass (limited by backpack) ->
-- stand on a Sell Pad -> Grass becomes Coins. Every client request is
-- validated here (cooldown, distance, capacity); the client only asks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Tools = require(Shared.Config.Tools)
local Backpacks = require(Shared.Config.Backpacks)
local Zones = require(Shared.Config.Zones)

local ProfileService = require(script.Parent.ProfileService)
local GrassService = require(script.Parent.GrassService)

local EconomyService = {}

local lastSwingAt: { [Player]: number } = {}
local remotes: Folder

local function capacityOf(profile): number
	local pack = Backpacks.ById[profile.EquippedBackpackId]
	return pack and pack.Capacity or 10
end

local function buffStacks(profile, buffId: string): number
	return profile.BuffStacks[buffId] or 0
end

-- Effective swing stats after buffs. Kept in one place so HUD, server
-- validation and balance tests all agree.
function EconomyService.GetSwingStats(profile)
	local tool = Tools.ById[profile.EquippedToolId] or Tools.List[1]
	local radius = tool.Radius * (1 + 0.25 * buffStacks(profile, "grass_magnet"))
	local critChance = 0.05 * buffStacks(profile, "golden_blades")
	return tool, radius, critChance
end

local function tryCut(player: Player)
	local profile = ProfileService.Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not profile or not root then
		return
	end
	local tool, radius, critChance = EconomyService.GetSwingStats(profile)

	-- Rate limit: one RemoteEvent can never swing faster than the tool.
	local now = os.clock()
	if now - (lastSwingAt[player] or 0) < tool.Cooldown then
		return
	end
	lastSwingAt[player] = now

	local feedback = remotes:FindFirstChild("CutFeedback") :: RemoteEvent
	local capacity = capacityOf(profile)
	if profile.Grass >= capacity then
		(remotes:FindFirstChild("Notify") :: RemoteEvent):FireClient(player, "Storage full! Sell your grass.")
		feedback:FireClient(player, 0, true)
		-- Auto-Sell Conveyor (final-zone automation) empties it for you.
		if buffStacks(profile, "auto_sell") > 0 then
			EconomyService.SellAll(player)
		end
		return
	end

	-- Locked zones cannot be farmed by standing on the fence line.
	local cells = GrassService.GetCellsInRadius(root.Position, radius, function(zoneId)
		return profile.UnlockedZoneIds[zoneId] == true
	end)

	local harvested = 0
	local hit = 0
	local cutAt: { Vector3 } = {} -- where to burst clippings on the client (capped)
	for _, cell in cells do
		hit += 1
		if GrassService.Damage(cell, tool.Power) then
			if #cutAt < 40 then
				table.insert(cutAt, cell.Center)
			end
			local gain = 1
			if math.random() < critChance then
				gain = 3 -- Golden Blades critical cut
			end
			harvested += gain
		end
	end

	local stored = 0
	if harvested > 0 then
		stored = math.min(harvested, capacity - profile.Grass)
		profile.Grass += stored
		profile.LifetimeGrass += harvested
		ProfileService.NotifyChanged(player)
	end
	-- Client plays snip/mow sounds and shows "+N"; hit > 0 with stored = 0
	-- means tough grass that only got shorter.
	feedback:FireClient(player, stored, profile.Grass >= capacity, hit, cutAt)
end

function EconomyService.SellAll(player: Player)
	local profile = ProfileService.Get(player)
	if not profile or profile.Grass <= 0 then
		return
	end
	-- Value uses the best unlocked zone the grass *could* be from; per-tuft
	-- origin tracking is a Phase-4 refinement (docs/DEVELOPMENT_PLAN.md).
	local bestValue = 1
	for zoneId in profile.UnlockedZoneIds do
		local zone = Zones.ById[zoneId]
		if zone and zone.GrassValue > bestValue then
			bestValue = zone.GrassValue
		end
	end
	local earned = profile.Grass * GameConfig.SellValuePerGrass * bestValue
	profile.Coins += earned
	profile.Grass = 0
	ProfileService.NotifyChanged(player);
	(remotes:FindFirstChild("Notify") :: RemoteEvent):FireClient(player, string.format("+%s Coins", tostring(earned)));
	(remotes:FindFirstChild("SellFeedback") :: RemoteEvent):FireClient(player, earned)
end

function EconomyService.Init(remoteFolder: Folder)
	remotes = remoteFolder;
	(remoteFolder:WaitForChild("CutRequest") :: RemoteEvent).OnServerEvent:Connect(tryCut)

	-- Sell pads are physical: tag any Part "SellPad" in Studio and it works.
	task.spawn(function()
		local pads = {}
		for _, instance in workspace:GetDescendants() do
			if instance:IsA("BasePart") and instance.Name == "SellPad" then
				table.insert(pads, instance)
			end
		end
		while true do
			task.wait(0.3)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					for _, pad in pads do
						if (root.Position - pad.Position).Magnitude < 8 then
							EconomyService.SellAll(player)
							break
						end
					end
				end
			end
		end
	end)
end

return EconomyService
