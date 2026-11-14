--!strict
-- One session owns each profile. Failed loads never become writable defaults.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Tuning = require(Shared.Config.Progression)
local Rules = require(Shared.ProgressionRules)
local Hay = require(Shared.Hay)
export type Profile = { [string]: any }
local ProfileService = {}
local profiles: { [Player]: Profile } = {}
local loading: { [Player]: boolean } = {}
local saving: { [Player]: boolean } = {}
local callbacks: { (Player, Profile) -> () } = {}
local session = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false)
local store: any = nil
if not RunService:IsStudio() then
	local ok, result = pcall(function() return DataStoreService:GetDataStore(GameConfig.DataStoreName) end)
	if ok then store = result else warn("[MowIt] DataStore unavailable:", result) end
end

local function defaults(): Profile
	local data = Rules.Defaults()
	data.Coins = GameConfig.StartingCoins
	data.GrassByVariant = {}
	data.LifetimeGrass = 0
	data.EquippedToolId = GameConfig.StartingToolId
	data.OwnedToolIds = { [GameConfig.StartingToolId] = true }
	data.EquippedBackpackId = GameConfig.StartingBackpackId
	data.OwnedBackpackIds = { [GameConfig.StartingBackpackId] = true }
	data.UnlockedZoneIds = { front_yard = true }
	data.BuffStacks = {}
	data.Level = 1
	data.Xp = 0
	data.Hay = Hay.Defaults()
	return data
end

local function reconcile(saved): Profile
	local data = defaults()
	if type(saved) == "table" then
		for key, value in data do
			if typeof(saved[key]) == typeof(value) then data[key] = saved[key] end
		end
		if saved.GrassByVariant == nil and type(saved.Grass) == "number" and saved.Grass > 0 then
			data.GrassByVariant.normal = saved.Grass
		end
	end
	return data
end

function ProfileService.OnChanged(callback) table.insert(callbacks, callback) end
function ProfileService.Get(player: Player): Profile? return profiles[player] end
function ProfileService.NotifyChanged(player: Player)
	local data = profiles[player]
	if data then
		for _, callback in callbacks do callback(player, data) end
	end
end

-- JSON roundtrip freezes the snapshot while UpdateAsync yields; nothing in a
-- profile is a Roblox datatype. No delayed save can overwrite a newer snapshot.
function ProfileService.Save(player: Player, release: boolean?): boolean
	while saving[player] do task.wait() end
	local data = profiles[player]
	if not data then return false end
	if not store then
		if release then profiles[player] = nil end
		return RunService:IsStudio()
	end
	saving[player] = true
	local snapshot = HttpService:JSONDecode(HttpService:JSONEncode(data))
	snapshot.LastSeen = os.time()
	local saved = false
	for attempt = 1, Tuning.SaveAttempts do
		local owned = false
		local ok, err = pcall(function()
			store:UpdateAsync("player_" .. player.UserId, function(old)
				owned = false
				if not old or not old._Session or old._Session.Id ~= session then return nil end
				owned = true
				snapshot._Session = if release then nil else { Id = session, Expires = os.time() + Tuning.SessionLockSeconds }
				return snapshot, { player.UserId }
			end)
		end)
		if ok then saved = owned; break end
		warn("[MowIt] Save attempt failed:", player.UserId, err)
		if attempt < Tuning.SaveAttempts then task.wait(attempt) end
	end
	saving[player] = nil
	if release then profiles[player] = nil end
	if not saved and not release then player:Kick("Your progress could not be saved safely. Please rejoin.") end
	return saved
end

function ProfileService.Load(player: Player): Profile?
	if profiles[player] then return profiles[player] end
	if loading[player] then return nil end
	loading[player] = true
	local data = defaults()
	local loaded = RunService:IsStudio()
	if store then
		for attempt = 1, Tuning.SaveAttempts do
			local ok, result = pcall(function()
				return store:UpdateAsync("player_" .. player.UserId, function(old)
					local lock = type(old) == "table" and old._Session
					if lock and lock.Id ~= session and lock.Expires > os.time() then return nil end
					local nextData = reconcile(old)
					nextData._Session = { Id = session, Expires = os.time() + Tuning.SessionLockSeconds }
					return nextData, { player.UserId }
				end)
			end)
			if ok and result then data = reconcile(result); loaded = true; break end
			if attempt < Tuning.SaveAttempts then task.wait(attempt * 2) end
		end
	end
	loading[player] = nil
	if not loaded then
		player:Kick("Your progress is unavailable or open in another server. Please rejoin in a moment.")
		return nil
	end
	Rules.AccrueOffline(data, os.time())
	data.LastSeen = os.time()
	profiles[player] = data
	if player.Parent ~= Players then ProfileService.Save(player, true); return nil end
	ProfileService.NotifyChanged(player)
	return data
end

function ProfileService.Init()
	Players.PlayerAdded:Connect(ProfileService.Load)
	Players.PlayerRemoving:Connect(function(player) ProfileService.Save(player, true) end)
	for _, player in Players:GetPlayers() do task.spawn(ProfileService.Load, player) end
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function() ProfileService.Save(player, true); pending -= 1 end)
		end
		while pending > 0 do task.wait() end
	end)
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveSeconds)
			for player in profiles do task.spawn(ProfileService.Save, player) end
		end
	end)
end
return ProfileService
