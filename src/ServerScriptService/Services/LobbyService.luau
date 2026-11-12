--!strict
-- Lobby place only: step on the Join Pad -> join the queue (up to
-- GameConfig.MaxPartySize) -> countdown -> everybody teleports together
-- into a RESERVED server of the Land place (nobody else can join it), onto
-- the land of the party's host: the first player who stepped on the pad.
--
-- Modern API note: TeleportService:ReserveServer() is deprecated. The
-- current pattern is HttpService:GenerateGUID + TeleportOptions.ReservedServerId
-- + TeleportService:TeleportAsync (see docs/ARCHITECTURE.md for sources).
-- Teleporting does not work in Studio; there we log the would-be party
-- instead, so the whole flow can be playtested solo.

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local LobbyService = {}

local queue: { Player } = {}
local countdownRunning = false
local remotes: Folder?

local function broadcastQueue()
	if not remotes then
		return
	end
	local names = {}
	for _, player in queue do
		table.insert(names, player.DisplayName)
	end
	(remotes:FindFirstChild("QueueUpdated") :: RemoteEvent):FireAllClients(names, GameConfig.MaxPartySize)
end

local function removeFromQueue(player: Player)
	local index = table.find(queue, player)
	if index then
		table.remove(queue, index)
		broadcastQueue()
	end
end

local function startMatch()
	countdownRunning = false
	if #queue == 0 then
		return
	end
	local party = table.clone(queue)
	table.clear(queue)
	broadcastQueue()

	if RunService:IsStudio() or GameConfig.LandPlaceId == 0 then
		print(("[MowIt][Lobby] Would teleport %d player(s) to the land of the first: %s"):format(
			#party,
			table.concat(
				(function()
					local names = {}
					for _, p in party do
						table.insert(names, p.Name)
					end
					return names
				end)(),
				", "
			)
		))
		return
	end

	local options = Instance.new("TeleportOptions")
	options.ReservedServerId = HttpService:GenerateGUID(false)
	options:SetTeleportData({ PartySize = #party, HostUserId = party[1].UserId })

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(GameConfig.LandPlaceId, party, options)
	end)
	if not ok then
		warn("[MowIt][Lobby] Teleport failed:", err)
		-- Put everyone back so they can try again instead of losing the party.
		for _, player in party do
			table.insert(queue, player)
		end
		broadcastQueue()
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
			if remotes then
				(remotes:FindFirstChild("QueueUpdated") :: RemoteEvent):FireAllClients(
					(function()
						local names = {}
						for _, p in queue do
							table.insert(names, p.DisplayName)
						end
						return names
					end)(),
					GameConfig.MaxPartySize,
					remaining
				)
			end
			if #queue >= GameConfig.MaxPartySize then
				break -- full party starts immediately
			end
			task.wait(1)
			remaining -= 1
		end
		startMatch()
	end)
end

function LobbyService.Init(remoteFolder: Folder)
	remotes = remoteFolder

	local lobbyFolder = workspace:WaitForChild("Lobby", 10)
	local pad = lobbyFolder and lobbyFolder:FindFirstChild("JoinPad") :: BasePart?
	if not pad then
		warn("[MowIt][Lobby] Workspace/Lobby/JoinPad not found — GrayboxService should have created it.")
		return
	end

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
		if table.find(queue, player) then
			removeFromQueue(player) -- stepping again leaves the queue
		elseif #queue < GameConfig.MaxPartySize then
			table.insert(queue, player)
			broadcastQueue()
			ensureCountdown()
		end
	end)

	Players.PlayerRemoving:Connect(removeFromQueue)
end

return LobbyService
