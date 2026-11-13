--!strict
-- The game-action boundary. No currency, position, reward or price comes from the client.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Config.Progression)
local Zones = require(Shared.Config.Zones)
local Rules = require(Shared.ProgressionRules)
local GrassBag = require(Shared.GrassBag)
local Profiles = require(script.Parent.ProfileService)
local Land = require(script.Parent.LandService)
local Crew = require(Shared.Config.Crew)
local Contracts = require(script.Parent.ContractService)
local Quests = require(script.Parent.QuestService)
local Plots = require(script.Parent.PlotService)
local Lawn = require(Shared.PlantingPlots)
local ProgressionService = {}
local lastRequest = {}
local confirmUntil = {}
local remotes: Folder

local function notify(player, text)
	(remotes.Notify :: RemoteEvent):FireClient(player, text)
end

function ProgressionService.Tutorial(player: Player)
	local profile = Profiles.Get(player)
	if not profile or not remotes then return end
	while true do
		local step = Tuning.Tutorial[profile.TutorialStep]
		if not step then break end
		local complete = (step.Id == "cut" and profile.LifetimeGrass >= step.Target)
			or (step.Id == "sell" and profile.SellCount >= step.Target)
			or (step.Id == "tool" and profile.OwnedToolIds.safety_scissors)
			or (step.Id == "expansion" and profile.UnlockedZoneIds.backyard)
		if not complete then break end
		Rules.AwardCoins(profile, step.Coins)
		profile.Clovers += step.Clovers
		profile.TutorialStep += 1
		notify(player, "Objective complete! Coins and Clovers collected.")
	end
end

local function action(player: Player, name: any, id: any)
	if type(name) ~= "string" or #name > 32 or type(id) ~= "string" or #id > 64 then return end
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < Tuning.ActionCooldown then return end
	lastRequest[player] = now
	local profile = Profiles.Get(player)
	if not profile then return end
	local message = ""
	if name == "BuyCrew" then
		local epoch, shelf = Rules.Shelf(os.time())
		if profile.MarketEpoch ~= epoch then profile.MarketEpoch = epoch; profile.MarketBought = {} end
		for _, row in shelf do
			if row.Id ~= id then continue end
			local def = Rules.CrewDef(id)
			local bought = profile.MarketBought[id] or 0
			if not profile.UnlockedZoneIds[def.Expansion] then message = "Unlock the Crew's expansion first."; break end
			if bought >= row.Stock then message = "Your stock is sold out until the next restock."; break end
			if profile.Clovers < row.Price then message = "Not enough Clovers. Complete jobs or keep mowing."; break end
			if not Rules.AddCrew(profile, id) then message = "Crew roster is full."; break end
			profile.Clovers -= row.Price
			profile.MarketBought[id] = bought + 1
			message = "Welcome, " .. def.DisplayName .. "! Equip them in Crew."
			break
		end
	elseif name == "EquipCrew" then
		local entry = profile.Crew[id]
		local index = table.find(profile.EquippedCrew, id)
		if index then table.remove(profile.EquippedCrew, index)
		elseif entry and #profile.EquippedCrew < Rules.CrewSlots(profile) then table.insert(profile.EquippedCrew, id)
		else message = "No free Crew slots." end
	elseif name == "MergeCrew" then
		message = if Rules.MergeCrew(profile, id) then "Crew evolved!" else "You need three copies of the same Crew and evolution."
	elseif name == "CrewMode" then
		local entry = profile.Crew[id]
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if entry and table.find(profile.EquippedCrew, id) and root then
			if entry.Mode == "Station" then entry.Mode = "Follow"; entry.Position = nil
			elseif Land.IsHost(player) then
				for _, zone in Zones.List do
					local folder = workspace.Zones:FindFirstChild(zone.Id)
					if not profile.UnlockedZoneIds[zone.Id] then continue end
					if Lawn.Contains(folder, root.Position) then
						entry.Mode = "Station"; entry.ZoneId = zone.Id
						entry.Position = { root.Position.X, root.Position.Y, root.Position.Z }
						message = "Crew stationed here. Offline work needs automation or an offline upgrade."
						break
					end
				end
			else message = "Station Crew on your own land." end
		end
	elseif name == "Contract" then message = Contracts.Accept(player, id)
	elseif name == "AbandonContract" then message = Contracts.Abandon(player)
	elseif name == "Plant" then message = Plots.Plant(player, id)
	elseif name == "CollectOffline" then
		if not Land.IsHost(player) then message = "Collect offline grass on your own land."
		else
			local stored = GrassBag.Add(profile, "normal", profile.OfflineGrass)
			profile.OfflineGrass -= stored
			message = if stored > 0 then "Offline grass collected. Walk to SELL to cash it in." else "No grass collected. Check your storage and offline production."
		end
	elseif name == "Daily" then
		local time = os.time()
		local ready, streak = Rules.DailyStatus(profile, time)
		if not ready then message = "Your next daily reward is not ready yet."
		else
			profile.DailyClaimAt = time; profile.DailyStreak = streak
			Rules.AwardCoins(profile, Tuning.DailyCoins[streak])
			profile.Clovers += Tuning.DailyClovers[streak]
			message = "Day " .. streak .. " reward collected!"
		end
	elseif name == "FranchisePreview" then
		if not Land.IsHost(player) then message = "Franchise on your own land."
		elseif Rules.FranchiseAward(profile) <= 0 then message = "Unlock Mega Fields and reach the required run earnings first."
		else
			confirmUntil[player] = now + 30;
			(remotes.FranchiseOffer :: RemoteEvent):FireClient(player, Rules.FranchiseAward(profile))
		end
	elseif name == "FranchiseConfirm" then
		if Land.IsHost(player) and (confirmUntil[player] or 0) >= now then
			confirmUntil[player] = nil
			if Rules.Franchise(profile) then
				Contracts.Abandon(player)
				local spawn = workspace:FindFirstChild("GameSpawn", true) -- inside the player's base model
				if spawn and spawn:IsA("BasePart") and player.Character then player.Character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0)) end
				message = "New franchise started! Your Crew and permanent upgrades are safe."
			end
		end
	elseif name == "BuyNode" then message = if Rules.BuyNode(profile, id) then "Permanent upgrade purchased!" else "Not enough points, or this upgrade is maxed."
	end
	ProgressionService.Tutorial(player)
	Profiles.NotifyChanged(player)
	if message ~= "" then notify(player, message) end
end

function ProgressionService.OnCut(player: Player, zoneId: string, amount: number)
	local profile = Profiles.Get(player)
	if not profile or amount <= 0 then return end
	profile.Clovers += amount * Tuning.CloversPerGrass
	Contracts.OnCut(player, zoneId, amount)
	if math.random() < Tuning.DiscoveryChance then
		local candidates, total = {}, 0
		for _, def in Crew.List do
			if def.Expansion == zoneId then
				total += Tuning.Market[def.Rarity].Chance
				table.insert(candidates, { Def = def, Until = total })
			end
		end
		local roll = math.random() * total
		for _, row in candidates do
			if roll <= row.Until then
				if Rules.AddCrew(profile, row.Def.Id) then notify(player, "Shining grass! You found " .. row.Def.DisplayName .. ".") end
				break
			end
		end
	end
end

function ProgressionService.Init(folder: Folder, economy)
	remotes = folder
	Contracts.Init(folder);
	Quests.Init(folder);
	(folder.GameAction :: RemoteEvent).OnServerEvent:Connect(action)
	Players.PlayerRemoving:Connect(function(player) lastRequest[player] = nil; confirmUntil[player] = nil end)
	task.spawn(function()
		while true do
			task.wait(Tuning.CrewTickSeconds)
			for _, player in Players:GetPlayers() do
				local profile = Profiles.Get(player)
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if not profile or not root or not humanoid or humanoid.Health <= 0 then continue end
				for index, uid in profile.EquippedCrew do
					local entry = profile.Crew[uid]
					local def = entry and Rules.CrewDef(entry.Id)
					if not def then continue end
					local position = root.Position + Vector3.new(math.cos(index * 2) * Tuning.CrewFollowSpacing, 0, math.sin(index * 2) * Tuning.CrewFollowSpacing)
					if entry.Mode == "Station" then
						if not Land.IsHost(player) or not entry.Position or not Land.IsUnlocked(entry.ZoneId) then continue end
						position = Vector3.new(table.unpack(entry.Position))
					end
					local power = def.Power * Tuning.EvolutionPower ^ entry.Evolution * (1 + (profile.FranchiseRanks.crew_engine or 0) * Tuning.CrewPowerPerRank)
					economy.Harvest(player, position, Tuning.CrewRadius, power, 0, false)
				end
				local automation = (profile.BuffStacks.gardener_helper or 0) + (profile.BuffStacks.mower_drone or 0) + (profile.BuffStacks.robot_crew or 0)
				if automation > 0 then
					local tool, radius = economy.GetSwingStats(profile)
					economy.Harvest(player, root.Position, radius, tool.Power * automation, 0, false)
				end
			end
		end
	end)
end
return ProgressionService
