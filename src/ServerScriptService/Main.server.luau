--!strict
-- Mow It! server entry point. One codebase, two places:
--   * Lobby place (start place) -> queue pad + teleport (LobbyService)
--   * Game place                -> mowing loop (Grass/Economy/Shop)
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
local LobbyService = require(Services.LobbyService)
local GrayboxService = require(Services.GrayboxService)
local ToolVisualService = require(Services.ToolVisualService)

-- Remotes -------------------------------------------------------------------
-- Created by the server in ReplicatedStorage/Remotes so client and server
-- always agree on the list without hand-building instances in Studio.
local REMOTE_NAMES = {
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
local isGamePlace = placeId == GameConfig.GamePlaceId
if RunService:IsStudio() or placeId == 0 then
	-- Unpublished/Studio: run everything against the graybox.
	isLobbyPlace = true
	isGamePlace = true
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
		leaderstats.Parent = player
	end
	(leaderstats:FindFirstChild("Coins") :: IntValue).Value = profile.Coins;
	(leaderstats:FindFirstChild("Grass") :: IntValue).Value = profile.Grass

	-- The client recomputes derived numbers (capacity, prices) from the
	-- same Shared configs, so we only ship raw profile state.
	profileRemote:FireClient(player, profile)
end

ProfileService.OnChanged(syncProfile)

-- Boot ------------------------------------------------------------------------
if isGamePlace then
	GrayboxService.BuildZonesIfMissing()
	GrassService.Init()
	EconomyService.Init(remotes)
	ToolVisualService.Init()
	ShopService.Init(remotes);
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

	-- Same, from the HUD's "+1M (Studio)" button (Shop.client.luau).
	local devRemote = Instance.new("RemoteEvent")
	devRemote.Name = "DevGiveCoins"
	devRemote.OnServerEvent:Connect(function(player)
		give:Invoke(player, 1_000_000)
	end)
	devRemote.Parent = remotes
end

-- Players who joined before ProfileService.Init connected get loaded here.
for _, player in Players:GetPlayers() do
	if not ProfileService.Get(player) then
		local profile = ProfileService.Load(player)
		syncProfile(player, profile)
	end
end

if GameConfig.Verbose then
	print(("[MowIt] Server booted. PlaceId=%d Lobby=%s Game=%s Studio=%s"):format(
		placeId,
		tostring(isLobbyPlace),
		tostring(isGamePlace),
		tostring(RunService:IsStudio())
	))
end
