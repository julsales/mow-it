--!strict
-- Grass visuals on the client. The grass itself is Terrain (GrassService):
-- tall Grass with wind-swayed blades, mowed cells turn into striped short
-- lawn, and Terrain edits replicate on their own. On top of it:
--   * GrassTufts draws each area's own blades (and the rare patches);
--   * this script sprays clippings, in the grass's color, where the local
--     player's swing mowed cells (positions arrive in CutFeedback).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GrassTufts = require(script.Parent:WaitForChild("GrassTufts"))

local player = Players.LocalPlayer
GrassTufts.Start()
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local POOL_SIZE = 120
local BITS_PER_CELL = 3
local MAX_BITS_PER_SWING = 60
local GREENS = {
	Color3.fromRGB(88, 164, 58),
	Color3.fromRGB(120, 186, 70),
	Color3.fromRGB(150, 204, 92),
	Color3.fromRGB(70, 140, 48),
}

local folder = Instance.new("Folder")
folder.Name = "Clippings (local)"
folder.Parent = Workspace

local pool: { BasePart } = {}
local nextBit = 1
for i = 1, POOL_SIZE do
	local bit = Instance.new("Part")
	bit.Name = "Clipping"
	bit.Size = Vector3.new(0.08, 0.05, 0.5)
	bit.Material = Enum.Material.SmoothPlastic
	bit.Anchored = true
	bit.CanCollide = false
	bit.CanQuery = false
	bit.CanTouch = false
	bit.CastShadow = false
	bit.Transparency = 1
	bit.Parent = folder
	pool[i] = bit
end

local function throw(from: Vector3, away: Vector3)
	local bit = pool[nextBit]
	nextBit = nextBit % POOL_SIZE + 1

	local spin = CFrame.Angles(math.random() * 6.28, math.random() * 6.28, math.random() * 6.28)
	local side = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 2
	local fling = away * (1 + math.random() * 2) + side
	local start = from + Vector3.new(0, 0.3, 0)
	local peak = start + fling * 0.5 + Vector3.new(0, 1.5 + math.random() * 1.5, 0)
	local landing = start + fling + Vector3.new(0, -0.3, 0)

	local own = GrassTufts.ColorAt(from)
	bit.Color = if own and math.random() < 0.7 then own else GREENS[math.random(#GREENS)]
	bit.Transparency = 0
	bit.CFrame = CFrame.new(start) * spin
	local rise = TweenService:Create(bit, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(peak) * spin * CFrame.Angles(2, 1, 0),
	})
	rise.Completed:Once(function()
		TweenService:Create(bit, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(landing) * spin * CFrame.Angles(4, 2, 1),
			Transparency = 1,
		}):Play()
	end)
	rise:Play()
end

(remotes:WaitForChild("CutFeedback") :: RemoteEvent).OnClientEvent:Connect(function(_stored, _full, _hit, cutAt: { Vector3 }?)
	if not cutAt or #cutAt == 0 then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local origin = if root then root.Position else cutAt[1]
	local perCell = math.max(1, math.min(BITS_PER_CELL, math.floor(MAX_BITS_PER_SWING / #cutAt)))
	local budget = MAX_BITS_PER_SWING
	for _, at in cutAt do
		local away = Vector3.new(at.X - origin.X, 0, at.Z - origin.Z)
		away = if away.Magnitude > 0.1 then away.Unit else Vector3.zero
		for _ = 1, perCell do
			if budget <= 0 then
				return
			end
			budget -= 1
			throw(at, away)
		end
	end
end)
