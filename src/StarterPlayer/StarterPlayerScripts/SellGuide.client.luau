--!strict
-- When storage is full: a big "STORAGE FULL!" banner and a glowing beam
-- from the player to the nearest sell pad in an unlocked zone. Selling is
-- physical (walk onto the pad), so the game shows the way instead of
-- offering a sell button. Local only; hides as soon as storage has room.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GrassBag = require(ReplicatedStorage:WaitForChild("Shared").GrassBag)
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local LandState = require(script.Parent:WaitForChild("LandState"))

local Guide = require(script.Parent:WaitForChild("WorldGuide"))
local Ui = require(script.Parent:WaitForChild("UiKit"))
local player = Players.LocalPlayer

-- Banner ------------------------------------------------------------------------
-- One banner and one beam, ever: drop leftovers if this script restarts.
local playerGui = player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("SellGuide")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "SellGuide"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Enabled = false
gui.Parent = playerGui

local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 70)
banner.Size = UDim2.fromOffset(340, 56)
banner.BackgroundColor3 = Color3.fromRGB(200, 60, 40)
banner.TextColor3 = Color3.new(1, 1, 1)
banner.Font = Enum.Font.GothamBlack
banner.TextScaled = true
banner.Text = "STORAGE FULL! Go sell"
banner.Parent = gui
do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = banner
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = banner
end

local function nearestPad(from: Vector3): BasePart?
	local zones = Workspace:FindFirstChild("Zones")
	if not zones then
		return nil
	end
	local best: BasePart?, bestDistance = nil, math.huge
	for _, zone in zones:GetChildren() do
		if LandState.IsUnlocked(zone.Name) then
			for _, d in zone:GetDescendants() do
				if d.Name == "SellPad" and d:IsA("BasePart") then
					local distance = (d.Position - from).Magnitude
					if distance < bestDistance then
						best, bestDistance = d, distance
					end
				end
			end
		end
	end
	return best
end

local active = false
local function setActive(on: boolean)
	active = on
	gui.Enabled = on and not Ui.MenuOpen
	if not on then Guide.Clear("Sell") end
end
Ui.MenuChanged:Connect(function(open) gui.Enabled = active and not open end)

ClientState.Changed:Connect(function(profile)
	setActive(GrassBag.IsFull(profile))
end)

-- Re-aim a few times a second (not every frame: pads don't move).
local nextAim = 0
RunService.Heartbeat:Connect(function()
	if not active then
		return
	end
	local now = os.clock()
	if now < nextAim then
		return
	end
	nextAim = now + 0.25
	local profile = ClientState.Get()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not profile or not root then
		return
	end
	local pad = nearestPad(root.Position)
	if not pad then
		Guide.Clear("Sell")
		return
	end
	Guide.Set("Sell", pad, 100, false)
end)

if ClientState.Get() then setActive(GrassBag.IsFull(ClientState.Get())) end
