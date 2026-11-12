--!strict
-- A Land session runs on ONE player's land: the host's (spec:
-- private-land-progression, lobby-showcase-and-party). The land shows the
-- expansions the host has unlocked, for everybody in the session:
--   * gates, walls, mowing and sell pads follow the HOST's expansions;
--   * only the host can buy expansions here;
--   * helpers keep earning for themselves (their own Coins, XP, tools and
--     sell value come from their own profile).
--
-- Who hosts: the lobby sends HostUserId with the party teleport; solo
-- sessions and Studio have no such data, so the first player hosts. If
-- the announced host never arrives, the first player present takes over.
--
-- The land's state is published as Workspace attributes (LandHostUserId,
-- LandHostName, LandUnlocked = "zone,zone,..."), so clients that join
-- late still get it (client side: StarterPlayerScripts/LandState.luau).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Zones = require(Shared.Config.Zones)

local ProfileService = require(script.Parent.ProfileService)

local LandService = {}

local HOST_WAIT_SECONDS = 30

local hostUserId: number? = nil
local hostName = ""
-- What the land looks like until the host's profile arrives: the starter yard.
local unlocked: { [string]: boolean } = { [Zones.List[1].Id] = true }

local function publish()
	local ids = {}
	for _, zone in Zones.List do
		if unlocked[zone.Id] then
			table.insert(ids, zone.Id)
		end
	end
	Workspace:SetAttribute("LandHostUserId", hostUserId or 0)
	Workspace:SetAttribute("LandHostName", hostName)
	Workspace:SetAttribute("LandUnlocked", table.concat(ids, ","))
end

local function setHost(userId: number, name: string)
	hostUserId = userId
	hostName = name
	local player = Players:GetPlayerByUserId(userId)
	local profile = player and ProfileService.Get(player)
	if profile then
		unlocked = table.clone(profile.UnlockedZoneIds)
	end
	publish()
end

-- The host the lobby announced for this session, if this player came from
-- the lobby. Teleport data passes through the client, so it is only trusted
-- for "whose land is this", never for anything worth currency.
local function announcedHost(player: Player): number?
	local joinData = player:GetJoinData()
	local data = joinData.TeleportData
	if joinData.SourcePlaceId ~= GameConfig.LobbyPlaceId or type(data) ~= "table" then
		return nil
	end
	local id = (data :: any).HostUserId
	return if type(id) == "number" and id > 0 and id == math.floor(id) then id else nil
end

local function onPlayerAdded(player: Player)
	if hostUserId == nil then
		local announced = announcedHost(player)
		if announced and announced ~= player.UserId then
			-- A helper arrived before the host: hold the land for the host.
			hostUserId = announced
			publish()
			task.delay(HOST_WAIT_SECONDS, function()
				if hostUserId == announced and not Players:GetPlayerByUserId(announced) then
					local first = Players:GetPlayers()[1]
					if first then
						setHost(first.UserId, first.DisplayName)
					end
				end
			end)
		else
			setHost(player.UserId, player.DisplayName)
		end
	elseif player.UserId == hostUserId then
		setHost(player.UserId, player.DisplayName)
	end
end

function LandService.IsHost(player: Player): boolean
	return player.UserId == hostUserId
end

function LandService.HostName(): string
	return hostName
end

-- Is this expansion open on the land of this session?
function LandService.IsUnlocked(zoneId: string): boolean
	return unlocked[zoneId] == true
end

-- Studio playtests: pretend the session belongs to someone else, to check
-- the helper experience solo (Main.server.luau exposes it as a dev hook).
function LandService.DevSetHost(userId: number, name: string, zoneIds: { string })
	hostUserId = userId
	hostName = name
	unlocked = {}
	for _, id in zoneIds do
		unlocked[id] = true
	end
	publish()
end

function LandService.Init()
	publish()
	-- The land follows the host's profile (loaded, or a new expansion bought).
	ProfileService.OnChanged(function(player, profile)
		if player.UserId == hostUserId then
			hostName = player.DisplayName
			unlocked = table.clone(profile.UnlockedZoneIds)
			publish()
		end
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return LandService
