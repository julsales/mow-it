--!strict
-- Keep movement upgrades server-owned and restore them after respawn.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Config.Progression)
local Tools = require(Shared.Config.Tools)
local Profiles = require(script.Parent.ProfileService)
local MovementService = {}
local function refresh(player: Player)
	local profile = Profiles.Get(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not profile or not humanoid then return end
	local tool = Tools.ById[profile.EquippedToolId]
	local ride = if tool and tool.Rideable and profile.Fuel > 0 then Tuning.RideSpeedMultiplier else 1
	humanoid.WalkSpeed = Tuning.BaseWalkSpeed * (1 + (profile.BuffStacks.swift_boots or 0) * Tuning.WalkSpeedPerBoot) * ride
end
function MovementService.Init()
	Profiles.OnChanged(refresh)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			if player.Character == character then refresh(player) end
		end)
		refresh(player)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do watch(player) end
end
return MovementService
