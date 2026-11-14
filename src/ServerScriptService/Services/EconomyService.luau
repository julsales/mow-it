--!strict
-- The core loop, server side: Cut -> carry Grass (limited by backpack) ->
-- hand it in at a "SellPad" (the baler's loading deck at the base, or an
-- island's drop-off pad) -> HayService presses it into bales the player
-- sells. Every client request is validated here (cooldown, distance,
-- capacity); the client only asks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tools = require(Shared.Config.Tools)
local Zones = require(Shared.Config.Zones)
local CompanyLevel = require(Shared.Config.CompanyLevel)
local GrassBag = require(Shared.GrassBag)

local ProfileService = require(script.Parent.ProfileService)
local GrassService = require(script.Parent.GrassService)
local LevelService = require(script.Parent.LevelService)
local LandService = require(script.Parent.LandService)
local HayService = require(script.Parent.HayService)

local Tuning = require(Shared.Config.Progression)
local Rules = require(Shared.ProgressionRules)
local emptyFuel = {}
local Weather = require(script.Parent.WeatherService)
local Progression = require(script.Parent.ProgressionService)
local Plots = require(script.Parent.PlotService)

local EconomyService = {}

local lastSwingAt: { [Player]: number } = {}
local remotes: Folder

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
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not profile or not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	-- Only with a tool in hand (default hotbar; ToolBackpackService).
	if not (character :: Model):FindFirstChildOfClass("Tool") then
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
	if GrassBag.IsFull(profile) then
		-- No Notify here: the client's single STORAGE FULL banner
		-- (SellGuide.client.luau) already says it; notifying on every swing
		-- stacked messages while auto-mowing.
		feedback:FireClient(player, 0, true)
		-- Auto-Sell Conveyor (final-zone automation) empties it for you.
		if buffStacks(profile, "auto_sell") > 0 then
			EconomyService.SellAll(player)
		end
		return
	end

	if tool.FuelType ~= "None" and profile.Fuel <= 0 then
		if not emptyFuel[player] then
			emptyFuel[player] = true
			(remotes.Notify :: RemoteEvent):FireClient(player, "Out of fuel! Load grass at your Baler or a drop-off pad to refill for free.")
		end
		return
	end
	local stored, hit, cutAt = EconomyService.Harvest(player, root.Position, radius, tool.Power, critChance, true)
	if hit > 0 and tool.FuelType ~= "None" then
		profile.Fuel = math.max(0, profile.Fuel - (Tuning.FuelPerSwing[tool.FuelType] or 0))
		ProfileService.NotifyChanged(player)
	end
	feedback:FireClient(player, stored, GrassBag.IsFull(profile), hit, cutAt)
end

-- Shared harvest path for manual cuts and server-owned Crew/automation.
function EconomyService.Harvest(player: Player, position: Vector3, radius: number, power: number, critChance: number, manual: boolean)
	local profile = ProfileService.Get(player)
	if not profile or GrassBag.IsFull(profile) then
		if profile and EconomyService.CanSellAnywhere(player) then EconomyService.SellAll(player) end
		return 0, 0, {}
	end
	local cells = GrassService.GetCellsInRadius(position, radius, LandService.IsUnlocked)
	local stored, harvested, xp, hit = 0, 0, 0, 0
	-- Mature planted grass takes storage priority over the surrounding wild lawn.
	if manual then stored = Plots.CutNear(player, position, radius) end
	local cutAt = {}
	for _, cell in cells do
		if GrassBag.IsFull(profile) then break end
		hit += 1
		if GrassService.Damage(cell, power) then
			if #cutAt < 40 then table.insert(cutAt, cell.Center) end
			local gain = cell.Yield
			if math.random() < critChance then gain *= 3 end
			harvested += gain
			stored += GrassBag.Add(profile, Weather.Variant(profile), gain)
			xp += Zones.ById[cell.ZoneId].GrassValue * CompanyLevel.XpPerCutValue
			Progression.OnCut(player, cell.ZoneId, gain)
		end
	end
	if harvested > 0 or stored > 0 then
		profile.LifetimeGrass += harvested
		LevelService.AddXp(player, xp)
		if GrassBag.IsFull(profile) and EconomyService.CanSellAnywhere(player) then EconomyService.SellAll(player) end
		ProfileService.NotifyChanged(player)
	end
	return stored, hit, cutAt
end

function EconomyService.CanSellAnywhere(player: Player): boolean
	local profile = ProfileService.Get(player)
	return profile ~= nil and buffStacks(profile, "auto_sell") > 0
end

-- Pays out everything carried at once, skipping the hay yard: Auto-Sell
-- (remote selling), and places that have no yard.
function EconomyService.SellAll(player: Player)
	local profile = ProfileService.Get(player)
	if not profile or GrassBag.Total(profile) <= 0 then
		return
	end
	local earned = Rules.AwardCoins(profile, HayService.LoadValue(profile))
	profile.SellCount += 1
	GrassBag.Clear(profile)
	LevelService.AddXp(player, earned * CompanyLevel.XpPerCoinSold)
	ProfileService.NotifyChanged(player);
	(remotes:FindFirstChild("Notify") :: RemoteEvent):FireClient(player, string.format("+%s Coins", tostring(earned)));
	(remotes:FindFirstChild("SellFeedback") :: RemoteEvent):FireClient(player, earned)
end

-- Standing on a SellPad: the grass goes to the baler (bales to sell at the
-- base); without a hay yard it is paid out on the spot.
local function handIn(player: Player)
	if HayService.HasYard() then
		HayService.Load(player)
	else
		EconomyService.SellAll(player)
	end
end

function EconomyService.Init(remoteFolder: Folder)
	remotes = remoteFolder;
	Players.PlayerRemoving:Connect(function(player) lastSwingAt[player] = nil; emptyFuel[player] = nil end);
	(remoteFolder:WaitForChild("CutRequest") :: RemoteEvent).OnServerEvent:Connect(tryCut)

	-- Handing grass in is physical: name any Part "SellPad" in Studio and it works.
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
					-- Riding something big: the player sits high up and the
					-- machine is wide, so count the pad as reached when the
					-- machine is over it (not only the player's feet).
					local reach, height = 2, 8
					local ride = (character :: Model):FindFirstChild("ToolModel")
					if ride and ride:IsA("Model") and ride:GetAttribute("Ground") then
						local _, size = ride:GetBoundingBox()
						reach += math.min(size.X, size.Z) / 2
						height += size.Y
					end
					for _, pad in pads do
						local localPosition = pad.CFrame:PointToObjectSpace(root.Position)
						local zone = pad:FindFirstAncestorWhichIsA("Folder")
						if (not zone or not Zones.ById[zone.Name] or LandService.IsUnlocked(zone.Name))
							and math.abs(localPosition.X) <= pad.Size.X / 2 + reach
							and math.abs(localPosition.Z) <= pad.Size.Z / 2 + reach
							and math.abs(localPosition.Y) < height then
							local profile = ProfileService.Get(player)
							if profile and profile.Fuel < Tuning.FuelCapacity then
								profile.Fuel = Tuning.FuelCapacity; emptyFuel[player] = nil
								ProfileService.NotifyChanged(player)
							end
							handIn(player)
							break
						end
					end
				end
			end
		end
	end)
end

return EconomyService
