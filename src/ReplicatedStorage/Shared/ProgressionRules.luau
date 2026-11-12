--!strict
-- Pure progression rules; services own timing, remotes and world interaction.
local Config = script.Parent.Config
local Tuning = require(Config.Progression)
local Franchise = require(Config.Franchise)
local Crew = require(Config.Crew)
local Zones = require(Config.Zones)
local GameConfig = require(Config.GameConfig)
local Rules = {}

function Rules.Defaults()
	return {
		Clovers = 0, RunCoins = 0, LifetimeCoins = 0, SellCount = 0, Fuel = Tuning.FuelCapacity, Franchises = 0,
		FranchisePoints = 0, FranchiseRanks = {}, Crew = {}, EquippedCrew = {},
		NextCrewId = 1, MarketEpoch = -1, MarketBought = {}, Plots = {},
		LastSeen = 0, OfflineGrass = 0, DailyClaimAt = 0, DailyStreak = 0,
		TutorialStep = 1, KnownQuestContacts = {},
	}
end

function Rules.CrewSlots(profile): number
	local slots = Tuning.BaseCrewSlots + (profile.FranchiseRanks.extra_crew_slot or 0)
	for _, level in Tuning.CrewSlotLevels do
		if profile.Level >= level then slots += 1 end
	end
	return slots
end

function Rules.DailyStatus(profile, time: number): (boolean, number, number)
	local ready = time - profile.DailyClaimAt >= Tuning.DailySeconds
	local nextDay = if time - profile.DailyClaimAt < Tuning.DailySeconds * 2 then profile.DailyStreak % #Tuning.DailyCoins + 1 else 1
	return ready, if ready then nextDay else math.max(1, profile.DailyStreak), profile.DailyClaimAt + Tuning.DailySeconds
end

function Rules.CrewDef(id: string)
	for _, def in Crew.List do
		if def.Id == id then return def end
	end
	return nil
end

function Rules.CrewCount(profile): number
	local count = 0
	for _ in profile.Crew do count += 1 end
	return count
end

function Rules.AddCrew(profile, id: string): string?
	if not Rules.CrewDef(id) or Rules.CrewCount(profile) >= Tuning.MaxCrew then return nil end
	local uid = tostring(profile.NextCrewId)
	profile.NextCrewId += 1
	profile.Crew[uid] = { Id = id, Evolution = 0, Mode = "Follow", ZoneId = "front_yard" }
	return uid
end

function Rules.MergeCrew(profile, uid: string): boolean
	local chosen = profile.Crew[uid]
	if not chosen or chosen.Evolution >= Tuning.MaxEvolution then return false end
	local copies = { uid }
	for key, entry in profile.Crew do
		if key ~= uid and entry.Id == chosen.Id and entry.Evolution == chosen.Evolution then
			table.insert(copies, key)
			if #copies == Tuning.MergeCopies then break end
		end
	end
	if #copies < Tuning.MergeCopies then return false end
	for _, key in copies do
		if key ~= uid then
			profile.Crew[key] = nil
			local equipped = table.find(profile.EquippedCrew, key)
			if equipped then table.remove(profile.EquippedCrew, equipped) end
		end
	end
	chosen.Evolution += 1
	return true
end

function Rules.CoinMultiplier(profile): number
	local multiplier = 1 + (profile.FranchiseRanks.company_multiplier or 0) * Tuning.CoinMultiplierPerRank
	for _, uid in profile.EquippedCrew do
		local entry = profile.Crew[uid]
		local def = entry and Rules.CrewDef(entry.Id)
		if def then multiplier += def.MultiplierPercent / 100 * Tuning.EvolutionPower ^ entry.Evolution end
	end
	return multiplier
end

function Rules.AwardCoins(profile, amount: number): number
	local earned = math.floor(amount * Rules.CoinMultiplier(profile))
	profile.Coins += earned
	profile.RunCoins += earned
	profile.LifetimeCoins += earned
	return earned
end

function Rules.FranchiseAward(profile): number
	if not profile.UnlockedZoneIds[Zones.List[#Zones.List].Id] then return 0 end
	if profile.RunCoins < Franchise.FirstPointAtLifetimeCoins then return 0 end
	return 1 + math.floor(math.log(profile.RunCoins / Franchise.FirstPointAtLifetimeCoins) / math.log(Franchise.PointCostGrowth))
end

function Rules.Franchise(profile): boolean
	local points = Rules.FranchiseAward(profile)
	if points == 0 then return false end
	profile.FranchisePoints += points
	profile.Franchises += 1
	profile.Coins = GameConfig.StartingCoins
	profile.RunCoins = 0
	profile.GrassByVariant = {}
	profile.EquippedToolId = GameConfig.StartingToolId
	profile.OwnedToolIds = { [GameConfig.StartingToolId] = true }
	profile.EquippedBackpackId = GameConfig.StartingBackpackId
	profile.OwnedBackpackIds = { [GameConfig.StartingBackpackId] = true }
	profile.UnlockedZoneIds = { front_yard = true }
	profile.BuffStacks = {}
	profile.Fuel = Tuning.FuelCapacity
	profile.Level = 1
	profile.Xp = 0
	profile.Plots = {}
	for index = 2, 1 + (profile.FranchiseRanks.head_start or 0) do
		profile.UnlockedZoneIds[Zones.List[index].Id] = true
	end
	for _, entry in profile.Crew do entry.Mode = "Follow"; entry.Position = nil end
	while #profile.EquippedCrew > Rules.CrewSlots(profile) do table.remove(profile.EquippedCrew) end
	return true
end

function Rules.BuyNode(profile, id: string): boolean
	for _, node in Franchise.Nodes do
		if node.Id == id then
			local rank = profile.FranchiseRanks[id] or 0
			if rank >= node.MaxRank or profile.FranchisePoints < node.CostPerRank then return false end
			profile.FranchisePoints -= node.CostPerRank
			profile.FranchiseRanks[id] = rank + 1
			return true
		end
	end
	return false
end

function Rules.OfflineHours(profile): number
	local automation = 0
	for _, id in { "gardener_helper", "mower_drone", "robot_crew" } do automation += profile.BuffStacks[id] or 0 end
	return math.min(Tuning.MaxOfflineHours, automation * Tuning.OfflineHoursPerAutomation + (profile.FranchiseRanks.offline_cap or 0) * Tuning.OfflineHoursPerRank)
end

function Rules.AccrueOffline(profile, now: number)
	if profile.LastSeen <= 0 then return end
	local minutes = math.clamp(now - profile.LastSeen, 0, Rules.OfflineHours(profile) * 3600) / 60
	local amount = 0
	for _, uid in profile.EquippedCrew do
		local entry = profile.Crew[uid]
		local def = entry and Rules.CrewDef(entry.Id)
		if def and entry.Mode == "Station" and profile.UnlockedZoneIds[entry.ZoneId] then
			amount += def.OfflineRate * Tuning.EvolutionPower ^ entry.Evolution * minutes
		end
	end
	profile.OfflineGrass += math.floor(amount)
end

-- Every server uses the same epoch and deterministic seed, independent of mowing RNG.
function Rules.Shelf(now: number)
	local epoch = math.floor(now / Tuning.RestockSeconds)
	local rng = Random.new(epoch)
	local shelf = {}
	for _, def in Crew.List do
		local rarity = Tuning.Market[def.Rarity]
		if rng:NextNumber() < rarity.Chance then
			table.insert(shelf, { Id = def.Id, Price = rarity.Price * Zones.IndexById[def.Expansion], Stock = rarity.Stock })
		end
	end
	return epoch, shelf
end

return Rules
