--!strict
-- Lobby place only: the two ways into play (spec: lobby-showcase-and-party).
--   * PlayPad  -> the player goes alone to their own land.
--   * PartyPad -> joins the party queue (up to GameConfig.MaxPartySize);
--     after a countdown (or at once when full) everybody travels together
--     to the land of the HOST: the first player who stepped on the pad.
-- Both travel to a RESERVED server of the Land place (nobody else can join
-- it), carrying HostUserId so LandService knows whose land to load.
--
-- Modern API note: TeleportService:ReserveServer() is deprecated. The
-- current pattern is HttpService:GenerateGUID + TeleportOptions.ReservedServerId
-- + TeleportService:TeleportAsync (see docs/ARCHITECTURE.md for sources).
-- Teleporting does not work in Studio; there the party is logged and, when
-- the land is built in the same world (combined mode), walked over to it.

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local LobbyService = {}

local queue: { Player } = {}
local countdownRunning = false
local remotes: Folder?

local function notify(player: Player, message: string)
	local remote = remotes and remotes:FindFirstChild("Notify") :: RemoteEvent?
	if remote and player.Parent then
		remote:FireClient(player, message)
	end
end

local function queueNames(): { string }
	local names = {}
	for _, player in queue do
		table.insert(names, player.DisplayName)
	end
	return names
end

local function broadcastQueue(countdown: number?)
	if remotes then
		(remotes:FindFirstChild("QueueUpdated") :: RemoteEvent):FireAllClients(queueNames(), GameConfig.MaxPartySize, countdown)
	end
end

local function removeFromQueue(player: Player)
	local index = table.find(queue, player)
	if index then
		table.remove(queue, index)
		broadcastQueue()
	end
end

-- Sends a party to the host's land. Returns false when the teleport could
-- not start, so callers can keep the party together.
local function travel(party: { Player }, host: Player): boolean
	if RunService:IsStudio() or GameConfig.LandPlaceId == 0 then
		local names = {}
		for _, player in party do
			table.insert(names, player.Name)
		end
		print(("[MowIt][Lobby] Would teleport to %s's land: %s"):format(host.Name, table.concat(names, ", ")))
		-- Studio combined mode: the land is right there, walk them over.
		local landSpawn = Workspace:FindFirstChild("GameSpawn")
		if landSpawn and landSpawn:IsA("BasePart") then
			for i, player in party do
				local character = player.Character
				if character then
					character:PivotTo(landSpawn.CFrame * CFrame.new((i - 1) * 4, 4, 0))
				end
			end
		end
		return true
	end

	local options = Instance.new("TeleportOptions")
	options.ReservedServerId = HttpService:GenerateGUID(false)
	options:SetTeleportData({ PartySize = #party, HostUserId = host.UserId })
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(GameConfig.LandPlaceId, party, options)
	end)
	if not ok then
		warn("[MowIt][Lobby] Teleport failed:", err)
	end
	return ok
end

local function startParty()
	countdownRunning = false
	if #queue == 0 then
		return
	end
	local party = table.clone(queue)
	table.clear(queue)
	broadcastQueue()
	if not travel(party, party[1]) then
		-- Put everyone back so they can try again instead of losing the party.
		for _, player in party do
			if player.Parent then
				table.insert(queue, player)
				notify(player, "Couldn't travel. Your party is still together, trying again.")
			end
		end
		broadcastQueue()
		if #queue > 0 then
			task.delay(3, function()
				if #queue > 0 and not countdownRunning then
					countdownRunning = true
					startParty()
				end
			end)
		end
	end
end

local function ensureCountdown()
	if countdownRunning then
		return
	end
	countdownRunning = true
	task.spawn(function()
		local remaining = GameConfig.QueueCountdownSeconds
		while remaining > 0 and #queue > 0 do
			broadcastQueue(remaining)
			if #queue >= GameConfig.MaxPartySize then
				break -- full party starts immediately
			end
			task.wait(1)
			remaining -= 1
		end
		startParty()
	end)
end

-- Calls `onStep(player)` when a player's character steps on the pad, at
-- most once a second per player.
local function watchPad(pad: BasePart, onStep: (Player) -> ())
	local debounce: { [Player]: boolean } = {}
	pad.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or debounce[player] then
			return
		end
		debounce[player] = true
		task.delay(1, function()
			debounce[player] = nil
		end)
		onStep(player)
	end)
end

function LobbyService.Init(remoteFolder: Folder)
	remotes = remoteFolder

	local lobby = Workspace:WaitForChild("Lobby", 10)
	if not lobby then
		warn("[MowIt][Lobby] Workspace/Lobby not found — GrayboxService should have created it.")
		return
	end

	local playPad = lobby:FindFirstChild("PlayPad")
	if playPad and playPad:IsA("BasePart") then
		local leaving: { [Player]: boolean } = {}
		watchPad(playPad, function(player)
			if leaving[player] then
				return
			end
			removeFromQueue(player) -- going solo leaves the party
			leaving[player] = true
			notify(player, "Heading to your land...")
			if not travel({ player }, player) then
				notify(player, "Couldn't travel. Step on PLAY to try again.")
			end
			task.delay(5, function()
				leaving[player] = nil
			end)
		end)
	end

	-- "JoinPad" is the pad's name in lobbies built before PLAY and PARTY split.
	local partyPad = lobby:FindFirstChild("PartyPad") or lobby:FindFirstChild("JoinPad")
	if partyPad and partyPad:IsA("BasePart") then
		watchPad(partyPad, function(player)
			if table.find(queue, player) then
				removeFromQueue(player) -- stepping again leaves the queue
			elseif #queue < GameConfig.MaxPartySize then
				table.insert(queue, player)
				broadcastQueue()
				ensureCountdown()
			else
				notify(player, "This party is full.")
			end
		end)
	else
		warn("[MowIt][Lobby] Workspace/Lobby/PartyPad not found.")
	end

	Players.PlayerRemoving:Connect(removeFromQueue)
	-- A teleport that fails after it started (per player): tell them, they
	-- are still in the lobby and can step on a pad again.
	TeleportService.TeleportInitFailed:Connect(function(player, _result, message)
		warn("[MowIt][Lobby] Teleport failed for", player.Name, message)
		notify(player, "Couldn't travel. Step on the pad to try again.")
	end)

	require(script.Parent.Lobby.Showcase).Init(lobby)
end

return LobbyService
