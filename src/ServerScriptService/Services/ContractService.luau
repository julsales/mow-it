--!strict
-- One cooperative job per land. Only the participants present at acceptance
-- earn rewards; a late join cannot claim another party's finished work.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.Contracts)
local Zones = require(Shared.Config.Zones)
local Rules = require(Shared.ProgressionRules)
local Profiles = require(script.Parent.ProfileService)
local Levels = require(script.Parent.LevelService)
local Land = require(script.Parent.LandService)
local ContractService = {}
local active: any = nil
local remotes: Folder
local function publish()
	workspace:SetAttribute("ContractId", if active then active.Def.Id else "")
	workspace:SetAttribute("ContractProgress", if active then active.Progress else 0)
	workspace:SetAttribute("ContractTarget", if active then active.Target else 0)
	workspace:SetAttribute("ContractEndsAt", if active then active.EndsAt else 0)
	workspace:SetAttribute("ContractZone", if active then active.ZoneId else "")
end
function ContractService.Accept(player: Player, id: string): string
	if not Land.IsHost(player) then return "Only the land owner can choose a party job." end
	if active then return "Finish or abandon the current job first." end
	local profile = Profiles.Get(player)
	if not profile then return "Profile is loading." end
	for _, def in Config.Bands do
		if def.Id == id then
			local zone = Zones.List[def.MinExpansion]
			if not Land.IsUnlocked(zone.Id) or not profile.UnlockedZoneIds[zone.Id] then return "Unlock that expansion first." end
			local members = {}
			for _, member in Players:GetPlayers() do
				local data = Profiles.Get(member)
				if data and Zones.HighestUnlockedIndex(data.UnlockedZoneIds) >= def.MinExpansion then members[member.UserId] = true end
			end
			local count = 0
			for _ in members do count += 1 end
			active = { Def = def, ZoneId = zone.Id, Members = members, Progress = 0,
				Target = math.ceil(def.GrassTarget * (1 + Config.PartyTargetPerExtraMember * math.max(0, count - 1))),
				EndsAt = workspace:GetServerTimeNow() + def.DeadlineSeconds }
			publish()
			return "Job started: mow in " .. zone.DisplayName .. "."
		end
	end
	return "Unknown job."
end
function ContractService.Abandon(player: Player): string
	if not Land.IsHost(player) then return "Only the land owner can abandon a party job." end
	active = nil; publish()
	return "Job abandoned. You can accept another."
end
function ContractService.OnCut(player: Player, zoneId: string, amount: number)
	if not active or not active.Members[player.UserId] or active.ZoneId ~= zoneId then return end
	active.Progress += amount
	if active.Progress < active.Target then publish(); return end
	local job = active
	active = nil; publish()
	local fraction = if workspace:GetServerTimeNow() <= job.EndsAt then 1 else Config.LatePayoutFraction
	for _, member in Players:GetPlayers() do
		local profile = Profiles.Get(member)
		if profile and job.Members[member.UserId] then
			Rules.AwardCoins(profile, job.Def.Coins * fraction)
			profile.Clovers += math.floor(job.Def.Clovers * fraction)
			Levels.AddXp(member, job.Def.Xp * fraction)
			Profiles.NotifyChanged(member);
			(remotes.Notify :: RemoteEvent):FireClient(member, if fraction == 1 then "Job complete! Rewards delivered." else "Job complete — late delivery rewards collected.")
		end
	end
end
function ContractService.Init(folder: Folder) remotes = folder; publish() end
return ContractService
