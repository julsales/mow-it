--!strict
-- Boat travel (Shared/Config/Travel.luau): a player on a jetty they may use
-- sails to another one. The client asks (remote "Travel", a destination
-- name: Jetties.Home or an island id); everything is checked here: they
-- must stand by one of their jetties (an island they unlocked, or their
-- own base), the destination must be theirs to go to, and trips have a
-- cooldown. The same remote tells the client the trip started, so it can
-- show the sea while the character is carried over.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Travel)
local Jetties = require(Shared.Jetties)

local ProfileService = require(script.Parent.ProfileService)

local TravelService = {}

local STAND = 3.5 -- studs above the deck a character is put down

local lastTrip: { [Player]: number } = {}

local function sail(player: Player, remote: RemoteEvent, destination: any)
	local profile = ProfileService.Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not profile or not root or not humanoid or humanoid.Health <= 0 or type(destination) ~= "string" then
		return
	end
	local now = os.clock()
	if now - (lastTrip[player] or -math.huge) < Config.Cooldown then
		return
	end
	local target = Jetties.Destination(player.UserId, profile.UnlockedZoneIds, destination)
	if not target then
		return
	end
	local boarded = false
	for name, jetty in Jetties.Usable(player.UserId, profile.UnlockedZoneIds) do
		if name ~= destination and (root.Position - jetty:GetPivot().Position).Magnitude <= Config.Distance then
			boarded = true
			break
		end
	end
	if not boarded then
		return
	end
	lastTrip[player] = now
	remote:FireClient(player, destination, Config.SailSeconds)
	-- Carried over halfway through, while the client's screen shows the sea.
	task.delay(Config.SailSeconds / 2, function()
		if player.Character == character and character.Parent and humanoid.Health > 0 then
			humanoid.Sit = false
			character:PivotTo(Jetties.Landing(target) + Vector3.new(0, STAND, 0))
		end
	end)
end

function TravelService.Init(remotes: Folder)
	local remote = remotes:WaitForChild("Travel") :: RemoteEvent
	remote.OnServerEvent:Connect(function(player, destination)
		sail(player, remote, destination)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastTrip[player] = nil
	end)
end

return TravelService
