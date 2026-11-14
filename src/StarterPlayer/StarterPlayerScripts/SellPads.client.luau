--!strict
-- Makes the islands' drop-off pads (contract name "SellPad": stand on one
-- and your grass is sent to the baler at your base) easy to spot without
-- cluttering the screen: a small "DROP OFF" sign above each pad (visible within ~60 studs, not through
-- walls) and a faint gold light column. Only pads in expansions open on
-- this session's land (LandState) get them. Pads are found by their contract name "SellPad"
-- (streaming-safe); local only.

local Workspace = game:GetService("Workspace")

local LandState = require(script.Parent:WaitForChild("LandState"))

local SIGN_DISTANCE = 60

type Decor = { Sign: BillboardGui, Light: BasePart, ZoneId: string? }
local decorated: { [BasePart]: Decor } = {}

local function zoneOf(pad: BasePart): string?
	-- Pads live in Workspace/Zones/<ZoneId>/...
	local zones = Workspace:FindFirstChild("Zones")
	local node: Instance? = pad
	while node and node.Parent ~= zones do
		node = node.Parent
	end
	return if node and zones then node.Name else nil
end

local function isUnlocked(zoneId: string?): boolean
	if not zoneId then
		return true -- pads outside zones always show
	end
	return LandState.IsUnlocked(zoneId)
end

local function decorate(pad: BasePart)
	-- The baler's own loading deck needs no sign: the machine is the sign.
	if decorated[pad] or pad:FindFirstAncestor("HayYard") then
		return
	end

	local sign = Instance.new("BillboardGui")
	sign.Name = "SellSign"
	sign.Size = UDim2.fromOffset(170, 40)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	sign.AlwaysOnTop = false
	sign.MaxDistance = SIGN_DISTANCE
	sign.LightInfluence = 0
	sign.Adornee = pad
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Color3.fromRGB(240, 180, 40)
	text.TextColor3 = Color3.fromRGB(60, 40, 0)
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.Text = "DROP OFF"
	text.Parent = sign
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = text
	local pad2 = Instance.new("UIPadding")
	pad2.PaddingTop = UDim.new(0, 4)
	pad2.PaddingBottom = UDim.new(0, 4)
	pad2.Parent = text
	sign.Parent = pad

	local width = math.min(pad.Size.X, pad.Size.Z) * 0.8
	local light = Instance.new("Part")
	light.Name = "SellLight"
	light.Shape = Enum.PartType.Cylinder
	light.Size = Vector3.new(10, width, width)
	light.CFrame = CFrame.new(pad.Position + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	light.Material = Enum.Material.Neon
	light.Color = Color3.fromRGB(255, 210, 80)
	light.Transparency = 0.93
	light.Anchored = true
	light.CanCollide = false
	light.CanQuery = false
	light.CanTouch = false
	light.CastShadow = false
	light.Parent = pad

	local decor: Decor = { Sign = sign, Light = light, ZoneId = zoneOf(pad) }
	decorated[pad] = decor
	local shown = isUnlocked(decor.ZoneId)
	sign.Enabled = shown
	light.Transparency = if shown then 0.93 else 1

	pad.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			decorated[pad] = nil
		end
	end)
end

local function refreshAll()
	for _, decor in decorated do
		local shown = isUnlocked(decor.ZoneId)
		decor.Sign.Enabled = shown
		decor.Light.Transparency = if shown then 0.93 else 1
	end
end

local function consider(instance: Instance)
	if instance.Name == "SellPad" and instance:IsA("BasePart") then
		decorate(instance)
	end
end

Workspace.DescendantAdded:Connect(consider)
for _, instance in Workspace:GetDescendants() do
	consider(instance)
end
LandState.Changed:Connect(refreshAll)
