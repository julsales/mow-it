--!strict
-- Shows how much grass a swing collected: one blade per unit jumps out of
-- the lawn where it was cut and flies into the player, one after another,
-- so the Nail Clipper's single blade reads as 1 and better tools as 2, 3,
-- 4... A "+N" rises over the player's head with the exact number.
-- Numbers: Config/GrassPickup. Colors: the grass that was cut (GrassTufts).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GrassPickup)
local Interface = require(Shared.Config.Interface)
local Format = require(Shared.Format)
local GrassTufts = require(script.Parent:WaitForChild("GrassTufts"))
local WorldPopup = require(script.Parent:WaitForChild("WorldPopup"))

local player = Players.LocalPlayer
local GrassPickup = {}

type Blade = { Part: BasePart, From: Vector3, StartAt: number, Spin: number, Busy: boolean }

local folder = Instance.new("Folder")
folder.Name = "GrassPickup (local)"
folder.Parent = Workspace

local blades: { Blade } = {}
for i = 1, Config.PoolSize do
	local part = Instance.new("WedgePart")
	part.Name = "Blade"
	part.Size = Config.Blade
	part.Material = if Config.Glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = folder
	blades[i] = { Part = part, From = Vector3.zero, StartAt = 0, Spin = 0, Busy = false }
end

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function freeBlade(): Blade?
	for _, blade in blades do
		if not blade.Busy then
			return blade
		end
	end
	return nil
end

local POP, HOLD, FLY = Config.PopSeconds, Config.HoldSeconds, Config.FlySeconds

RunService.RenderStepped:Connect(function()
	local root = rootPart()
	local now = os.clock()
	for _, blade in blades do
		if not blade.Busy then
			continue
		end
		local t = now - blade.StartAt
		if t < 0 then
			continue
		end
		local part = blade.Part
		local top = blade.From + Vector3.new(0, Config.PopHeight, 0)
		local position: Vector3, scale: number
		if t < POP then
			local a = 1 - (1 - t / POP) ^ 2
			position, scale = blade.From:Lerp(top, a), 0.4 + 0.6 * a
		elseif t < POP + HOLD or not root then
			position, scale = top, 1
		else
			local a = math.clamp((t - POP - HOLD) / FLY, 0, 1)
			position = top:Lerp(root.Position + Config.Target, a * a)
			scale = 1 + (Config.EndScale - 1) * a
		end
		if t >= POP + HOLD + FLY then
			blade.Busy = false
			part.Transparency = 1
		else
			part.Transparency = 0
			part.Size = Config.Blade * scale
			part.CFrame = CFrame.new(position) * CFrame.Angles(0, blade.Spin + t * 9, 0)
		end
	end
end)

local pendingPopup, popupQueued = 0, false
local function popup(amount: number)
	pendingPopup += amount
	if popupQueued then
		return
	end
	popupQueued = true
	task.delay(Config.Popup.Every, function()
		popupQueued = false
		local total = pendingPopup
		pendingPopup = 0
		local root = rootPart()
		if root and total > 0 then
			WorldPopup.Show(root.Position, "+" .. Format.Number(total), Interface.Colors.Leaf, Config.Popup)
		end
	end)
end

-- `amount` units of grass were stored; `from` are the spots they were cut
-- at (the player's feet when there are none).
function GrassPickup.Collect(amount: number, from: { Vector3 }?)
	amount = math.floor(amount + 0.5)
	local root = rootPart()
	if amount <= 0 or not root then
		return
	end
	local spots = if from and #from > 0 then from else { root.Position - Vector3.new(0, 2.5, 0) }
	local now = os.clock()
	for i = 1, math.min(amount, Config.MaxBlades) do
		local blade = freeBlade()
		if not blade then
			break
		end
		local spot = spots[(i - 1) % #spots + 1]
		-- Blades that share a spot stand in a small ring round it.
		local lap = (i - 1) // #spots
		local angle = i * 2.4
		local offset = if lap > 0 then Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.Spread * lap else Vector3.zero
		blade.Busy = true
		blade.From = GrassTufts.TakeSnip(spot) or spot + offset
		blade.StartAt = now + (i - 1) * Config.Stagger
		blade.Spin = angle
		blade.Part.Color = Color3.new():Lerp(GrassTufts.ColorAt(spot) or Interface.Colors.Leaf, Config.Brightness)
	end
	popup(amount)
end

return GrassPickup
