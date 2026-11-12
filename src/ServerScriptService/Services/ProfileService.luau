--!strict
-- Player profiles: session cache + DataStore persistence.
-- Server-authoritative. In Studio (or if the DataStore call fails) the
-- profile lives in memory only, so Play Solo always works for testing.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

export type Profile = {
	Coins: number,
	GrassByVariant: { [string]: number }, -- carried grass per variant (Shared/GrassBag.luau)
	LifetimeGrass: number,
	EquippedToolId: string,
	OwnedToolIds: { [string]: boolean },
	EquippedBackpackId: string,
	OwnedBackpackIds: { [string]: boolean },
	UnlockedZoneIds: { [string]: boolean },
	BuffStacks: { [string]: number },
	Level: number, -- Company Level (Shared/Config/CompanyLevel.luau)
	Xp: number, -- experience inside the current level
}

local ProfileService = {}

local store: DataStore? = nil
if not RunService:IsStudio() then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[MowIt] DataStore unavailable, running session-only:", result)
	end
end

local profiles: { [Player]: Profile } = {}
local changeCallbacks: { (Player, Profile) -> () } = {}

local function defaultProfile(): Profile
	return {
		Coins = GameConfig.StartingCoins,
		GrassByVariant = {},
		LifetimeGrass = 0,
		EquippedToolId = GameConfig.StartingToolId,
		OwnedToolIds = { [GameConfig.StartingToolId] = true },
		EquippedBackpackId = GameConfig.StartingBackpackId,
		OwnedBackpackIds = { [GameConfig.StartingBackpackId] = true },
		UnlockedZoneIds = { front_yard = true },
		BuffStacks = {},
		Level = 1,
		Xp = 0,
	}
end

-- Merge saved data over defaults so new fields never break old saves.
local function reconcile(saved: any): Profile
	local profile = defaultProfile()
	if type(saved) ~= "table" then
		return profile
	end
	for key, value in profile do
		if saved[key] ~= nil then
			(profile :: any)[key] = saved[key]
		end
	end
	-- Saves from before per-variant inventory carried one plain number.
	if type(saved.Grass) == "number" and saved.GrassByVariant == nil and saved.Grass > 0 then
		profile.GrassByVariant.normal = saved.Grass
	end
	return profile
end

function ProfileService.OnChanged(callback: (Player, Profile) -> ())
	table.insert(changeCallbacks, callback)
end

function ProfileService.NotifyChanged(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	for _, callback in changeCallbacks do
		callback(player, profile)
	end
end

function ProfileService.Get(player: Player): Profile?
	return profiles[player]
end

function ProfileService.Load(player: Player): Profile
	local profile = defaultProfile()
	if store then
		local ok, saved = pcall(function()
			return (store :: DataStore):GetAsync("player_" .. player.UserId)
		end)
		if ok then
			profile = reconcile(saved)
		else
			warn("[MowIt] Load failed for", player.Name, saved)
		end
	end
	profiles[player] = profile
	ProfileService.NotifyChanged(player)
	return profile
end

function ProfileService.Save(player: Player)
	local profile = profiles[player]
	if not profile or not store then
		return
	end
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync("player_" .. player.UserId, profile)
	end)
	if not ok then
		warn("[MowIt] Save failed for", player.Name, err)
	end
end

function ProfileService.Init()
	Players.PlayerAdded:Connect(function(player)
		ProfileService.Load(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		ProfileService.Save(player)
		profiles[player] = nil
	end)
	game:BindToClose(function()
		for player in profiles do
			ProfileService.Save(player)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveSeconds)
			for player in profiles do
				ProfileService.Save(player)
			end
		end
	end)
end

return ProfileService
