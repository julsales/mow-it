--!strict
-- Auto-mow: with a ground tool (mower, rider, tractor) walking is mowing,
-- the client asks to cut every tool cooldown; the server still validates
-- and rate-limits every request. (Sounds live in Audio.client.luau.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tools = require(Shared.Config.Tools)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local cutRequest = remotes:WaitForChild("CutRequest") :: RemoteEvent

-- The tool the local character is holding, from its model's attributes.
local function localTool(): (Model?, boolean)
	local character = player.Character
	local model = character and character:FindFirstChild("ToolModel") :: Model?
	return model, model ~= nil and model:GetAttribute("Ground") == true
end

-- Auto-mow --------------------------------------------------------------------------

local nextAutoCut = 0
RunService.Heartbeat:Connect(function()
	local model, ground = localTool()
	if not model or not ground then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.MoveDirection.Magnitude < 0.1 or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	if now < nextAutoCut then
		return
	end
	local tool = Tools.ById[(model:GetAttribute("ToolId") :: string?) or ""]
	local cooldown = tool and tool.Cooldown or 0.4
	nextAutoCut = now + cooldown * 1.05
	cutRequest:FireServer()
end)
