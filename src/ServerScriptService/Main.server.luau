--!strict
-- Mow It! server entry point. One codebase, two places:
--   * Lobby place (start place) -> queue pad + teleport (LobbyService)
--   * Land place                -> the host's land: mowing loop (Land/Grass/Economy/Shop)
-- Which one runs is decided by GameConfig place IDs; in Studio (PlaceId 0
-- for unpublished places) BOTH grayboxes are built so Play Solo can test
-- the loop and the queue without publishing anything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local Services = script.Parent:WaitForChild("Services")
local ProfileService = require(Services.ProfileService)
local GrassService = require(Services.GrassService)
local EconomyService = require(Services.EconomyService)
local ShopService = require(Services.ShopService)
local LevelService = require(Services.LevelService)
local LandService = require(Services.LandService)
local GrassBag = require(Shared.GrassBag)
local ProgressionService = require(Services.ProgressionService)
local WeatherService = require(Services.WeatherService)
local LobbyService = require(Services.LobbyService)
local GrayboxService = require(Services.GrayboxService)
local MapService = require(Services.MapService)
local ToolVisualService = require(Services.ToolVisualService)
local ToolArtService = require(Services.ToolArtService)

-- Remotes -------------------------------------------------------------------
-- Created by the server in ReplicatedStorage/Remotes so client and server
-- always agree on the list without hand-building instances in Studio.
local REMOTE_NAMES = {
	"GameAction",
	"FranchiseOffer",
	"QuestOffer",
	"RequestProfile",
	"CutRequest",
	"SellRequest",
	"BuyTool",
	"BuyBackpack",
	"BuyBuff",
	"UnlockZone",
	"Notify",
	"ProfileUpdated",
	"QueueUpdated",
	"CutFeedback", -- server -> client: (stored, storageFull, cellsHit, cutPositions) after each swing
	"SellFeedback", -- server -> client: (coinsEarned)
	"BuyFeedback", -- server -> client: (kind) after a successful purchase/unlock
	"LevelUp", -- server -> client: (newLevel) when the Company Level goes up
}

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in REMOTE_NAMES do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
end
remotes.Parent = ReplicatedStorage

-- Place detection -------------------------------------------------------------
local placeId = game.PlaceId
local isLobbyPlace = placeId == GameConfig.LobbyPlaceId
local isLandPlace = placeId == GameConfig.LandPlaceId
if RunService:IsStudio() or placeId == 0 then
	-- Unpublished/Studio: run everything against the graybox.
	isLobbyPlace = true
	isLandPlace = true
end

-- Profile -> client sync + leaderstats ---------------------------------------
local profileRemote = remotes:WaitForChild("ProfileUpdated") :: RemoteEvent

local function syncProfile(player: Player, profile)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		local coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Parent = leaderstats
		local grass = Instance.new("IntValue")
		grass.Name = "Grass"
		grass.Parent = leaderstats
		local level = Instance.new("IntValue")
		level.Name = "Level"
		level.Parent = leaderstats
		leaderstats.Parent = player
	end
	(leaderstats:FindFirstChild("Coins") :: IntValue).Value = profile.Coins;
	(leaderstats:FindFirstChild("Grass") :: IntValue).Value = GrassBag.Total(profile);
	(leaderstats:FindFirstChild("Level") :: IntValue).Value = profile.Level

	-- The client recomputes derived numbers (capacity, prices) from the
	-- same Shared configs, so we only ship raw profile state.
	profileRemote:FireClient(player, profile)
end

ProfileService.OnChanged(ProgressionService.Tutorial)
ProfileService.OnChanged(syncProfile)

-- Boot ------------------------------------------------------------------------
if isLandPlace then
	ToolArtService.Init() -- tool meshes first: the shop displays use them
	MapService.BuildIfMissing()
	require(Services.Map.ShopDisplay).Refresh() -- baked displays get the current tool art
	LandService.Init()
	GrassService.Init()
	LevelService.Init(remotes)
	EconomyService.Init(remotes)
	ProgressionService.Init(remotes, EconomyService)
	WeatherService.Init(remotes)
	ToolVisualService.Init()
	require(Services.ToolBackpackService).Init()
	require(Services.MovementService).Init()
	ShopService.Init(remotes)
	require(Services.Map.ShopDisplay).Init(ShopService.BuyTool)
	require(Services.Map.Gates).Init(ShopService.UnlockZone);
	(remotes:WaitForChild("SellRequest") :: RemoteEvent).OnServerEvent:Connect(function(player)
		-- Selling is physical (sell pads). Remote selling is only for players
		-- with Auto-Sell (later also a "Sell Anywhere" pass).
		if not EconomyService.CanSellAnywhere(player) then
			return
		end
		EconomyService.SellAll(player)
	end)
end

if isLobbyPlace then
	GrayboxService.BuildLobbyIfMissing()
	LobbyService.Init(remotes)
end

ProfileService.Init()

-- Studio-only test hooks (RunService:IsStudio() is false on live servers):
-- ServerStorage.DevGiveCoins:Invoke(player, amount)
-- lets playtests (and the Studio MCP) buy tools without grinding. Never
-- exists in a live server.
if RunService:IsStudio() then
	local inspect = Instance.new("BindableFunction")
	inspect.Name = "DevProfile"
	inspect.OnInvoke = function(player: Player, patch)
		local profile = ProfileService.Get(player)
		if profile and type(patch) == "table" then
			for key, value in patch do
				if profile[key] ~= nil and typeof(profile[key]) == typeof(value) then profile[key] = value end
			end
			ProfileService.NotifyChanged(player)
		end
		return profile
	end
	inspect.Parent = game:GetService("ServerStorage")
	local give = Instance.new("BindableFunction")
	give.Name = "DevGiveCoins"
	give.OnInvoke = function(player: Player, amount: number)
		local profile = ProfileService.Get(player)
		if profile then
			profile.Coins += amount
			ProfileService.NotifyChanged(player)
		end
		return profile and profile.Coins
	end
	give.Parent = game:GetService("ServerStorage")

	-- ServerStorage.DevGiveXp:Invoke(player, amount): same idea for levels.
	local giveXp = Instance.new("BindableFunction")
	giveXp.Name = "DevGiveXp"
	giveXp.OnInvoke = function(player: Player, amount: number)
		LevelService.AddXp(player, amount)
		ProfileService.NotifyChanged(player)
		local profile = ProfileService.Get(player)
		return profile and profile.Level
	end
	giveXp.Parent = game:GetService("ServerStorage")

	-- ServerStorage.DevSetLandHost:Invoke(userId, name, { zoneIds }): makes
	-- the session someone else's land, to try the helper experience solo.
	local setHost = Instance.new("BindableFunction")
	setHost.Name = "DevSetLandHost"
	setHost.OnInvoke = LandService.DevSetHost
	setHost.Parent = game:GetService("ServerStorage")

	-- Same, from the HUD's "+1M (Studio)" button (Shop.client.luau).
	local devRemote = Instance.new("RemoteEvent")
	devRemote.Name = "DevGiveCoins"
	devRemote.OnServerEvent:Connect(function(player)
		give:Invoke(player, 1_000_000)
	end)
	devRemote.Parent = remotes
end

-- A client can request its snapshot after binding listeners (late loading UI).
local lastSnapshot = {}
(remotes.RequestProfile :: RemoteEvent).OnServerEvent:Connect(function(player)
	local now = os.clock()
	if now - (lastSnapshot[player] or -math.huge) < 1 then return end
	lastSnapshot[player] = now
	local profile = ProfileService.Get(player)
	if profile then syncProfile(player, profile) end
end)
Players.PlayerRemoving:Connect(function(player) lastSnapshot[player] = nil end)

if GameConfig.Verbose then
	print(("[MowIt] Server booted. PlaceId=%d Lobby=%s Land=%s Studio=%s"):format(
		placeId,
		tostring(isLobbyPlace),
		tostring(isLandPlace),
		tostring(RunService:IsStudio())
	))
end
