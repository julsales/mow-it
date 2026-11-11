--!strict
-- When storage is full: a big "STORAGE FULL!" banner and a glowing beam
-- from the player to the nearest sell pad in an unlocked zone. Selling is
-- physical (walk onto the pad), so the game shows the way instead of
-- offering a sell button. Local only; hides as soon as storage has room.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Backpacks = require(ReplicatedStorage:WaitForChild("Shared").Config.Backpacks)
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local player = Players.LocalPlayer

-- Banner ------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "SellGuide"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

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

-- Beam --------------------------------------------------------------------------
local targetAnchor = Instance.new("Part")
targetAnchor.Name = "SellGuideTarget"
targetAnchor.Anchored = true
targetAnchor.CanCollide = false
targetAnchor.CanQuery = false
targetAnchor.CanTouch = false
targetAnchor.Transparency = 1
targetAnchor.Size = Vector3.one * 0.2
targetAnchor.Parent = Workspace
local targetAttachment = Instance.new("Attachment")
targetAttachment.Parent = targetAnchor

local beam = Instance.new("Beam")
beam.Name = "SellGuideBeam"
beam.Attachment1 = targetAttachment
beam.Color = ColorSequence.new(Color3.fromRGB(255, 210, 80))
beam.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.2),
	NumberSequenceKeypoint.new(1, 0.6),
})
beam.Width0 = 0.6
beam.Width1 = 0.6
beam.FaceCamera = true
beam.LightEmission = 0.6
beam.Segments = 2
beam.Enabled = false
beam.Parent = targetAnchor

local function isFull(profile): boolean
	local pack = Backpacks.ById[profile.EquippedBackpackId]
	local capacity = pack and pack.Capacity or 10
	return profile.Grass >= capacity
end

local function nearestPad(from: Vector3, profile): BasePart?
	local zones = Workspace:FindFirstChild("Zones")
	if not zones then
		return nil
	end
	local best: BasePart?, bestDistance = nil, math.huge
	for _, zone in zones:GetChildren() do
		if profile.UnlockedZoneIds[zone.Name] then
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
	gui.Enabled = on
	beam.Enabled = on
end

ClientState.Changed:Connect(function(profile)
	setActive(isFull(profile))
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
	local pad = nearestPad(root.Position, profile)
	if not pad then
		beam.Enabled = false
		return
	end
	targetAnchor.Position = pad.Position + Vector3.new(0, 1, 0)
	local source = root:FindFirstChild("SellGuideSource") :: Attachment?
	if not source then
		local a = Instance.new("Attachment")
		a.Name = "SellGuideSource"
		a.Position = Vector3.new(0, -1.5, 0)
		a.Parent = root
		source = a
	end
	beam.Attachment0 = source
	beam.Enabled = true
end)
