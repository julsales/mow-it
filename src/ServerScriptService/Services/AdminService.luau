--!strict
-- Admin test commands (Config/Admin decides who). The client panel
-- (AdminPanel.client) fires ReplicatedStorage/Remotes/AdminCommand; the
-- server checks the sender every time, validates every argument and
-- changes the profile through the same services the game uses.
-- Admins get the player attribute "Admin" so their client shows the panel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Admin = require(Shared.Config.Admin)
local Tools = require(Shared.Config.Tools)
local Zones = require(Shared.Config.Zones)

local ProfileService = require(script.Parent.ProfileService)
local LevelService = require(script.Parent.LevelService)

local AdminService = {}

local function isAdmin(player: Player): boolean
	if RunService:IsStudio() or table.find(Admin.UserIds, player.UserId) then
		return true
	end
	local ok, rank = pcall(player.GetRankInGroup, player, Admin.GroupId)
	return ok and rank >= Admin.MinGroupRank
end

local function teleport(player: Player, zoneId: string)
	local zones = workspace:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild(zoneId)
	local character = player.Character
	if not zone or not character then
		return
	end
	-- Next to the island's tool stand when there is one, else its centre.
	local stand = zone:FindFirstChild("FarmerStand", true)
	local target = if stand and stand:IsA("Model") then stand:GetPivot() * CFrame.new(0, 4, 10) else (zone :: Model):GetPivot() + Vector3.new(0, 6, 0)
	character:PivotTo(CFrame.new(target.Position))
end

local COMMANDS: { [string]: (Player, any, any) -> () } = {
	Coins = function(player, profile, amount)
		if table.find(Admin.Coins, amount) then
			profile.Coins += amount
		end
	end,
	Xp = function(player)
		LevelService.AddXp(player, Admin.Xp)
	end,
	GiveTool = function(player, profile, toolId)
		if typeof(toolId) == "string" and Tools.ById[toolId] then
			profile.OwnedToolIds[toolId] = true
			profile.EquippedToolId = toolId
		end
	end,
	GiveAllTools = function(player, profile)
		for _, def in Tools.List do
			profile.OwnedToolIds[def.Id] = true
		end
	end,
	UnlockZones = function(player, profile)
		for _, zone in Zones.List do
			profile.UnlockedZoneIds[zone.Id] = true
		end
	end,
	EmptyBag = function(player, profile)
		table.clear(profile.GrassByVariant)
	end,
	Teleport = function(player, profile, zoneId)
		if typeof(zoneId) == "string" then
			for _, zone in Zones.List do
				if zone.Id == zoneId then
					teleport(player, zoneId)
				end
			end
		end
	end,
	FastWalk = function(player)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local base = humanoid:GetAttribute("AdminBaseSpeed") or humanoid.WalkSpeed
			humanoid:SetAttribute("AdminBaseSpeed", base)
			humanoid.WalkSpeed = if humanoid.WalkSpeed > base then base else Admin.FastWalkSpeed
		end
	end,
}

function AdminService.Init(remotes: Folder)
	local remote = Instance.new("RemoteEvent")
	remote.Name = "AdminCommand"
	remote.Parent = remotes
	local last: { [Player]: number } = {}
	remote.OnServerEvent:Connect(function(player, command, argument)
		if not isAdmin(player) or typeof(command) ~= "string" or not COMMANDS[command] then
			return
		end
		local now = os.clock()
		if now - (last[player] or 0) < 0.15 then
			return -- spam guard
		end
		last[player] = now
		local profile = ProfileService.Get(player)
		if not profile then
			return
		end
		COMMANDS[command](player, profile, argument)
		ProfileService.NotifyChanged(player)
	end)
	local function mark(player: Player)
		task.spawn(function()
			player:SetAttribute("Admin", isAdmin(player))
		end)
	end
	Players.PlayerAdded:Connect(mark)
	for _, player in Players:GetPlayers() do
		mark(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)
end

return AdminService
