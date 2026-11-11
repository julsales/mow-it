--!strict
-- Makes every sell pad easy to find: a floating "💰 VENDER" sign that shows
-- through walls, plus a soft gold light column above the pad. Local only;
-- pads are found by their contract name "SellPad" (streaming-safe).

local Workspace = game:GetService("Workspace")

local decorated: { [BasePart]: boolean } = {}

local function decorate(pad: BasePart)
	if decorated[pad] then
		return
	end
	decorated[pad] = true

	local sign = Instance.new("BillboardGui")
	sign.Name = "SellSign"
	sign.Size = UDim2.fromOffset(180, 56)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	sign.AlwaysOnTop = true
	sign.MaxDistance = 400
	sign.LightInfluence = 0
	sign.Adornee = pad
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Color3.fromRGB(240, 180, 40)
	text.TextColor3 = Color3.fromRGB(60, 40, 0)
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.Text = "💰 VENDER"
	text.Parent = sign
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 14)
	c.Parent = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(120, 80, 0)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = text
	sign.Parent = pad

	local beam = Instance.new("Part")
	beam.Name = "SellLight"
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(16, math.min(pad.Size.X, pad.Size.Z) * 0.8, math.min(pad.Size.X, pad.Size.Z) * 0.8)
	beam.CFrame = CFrame.new(pad.Position + Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 210, 80)
	beam.Transparency = 0.85
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Parent = pad

	pad.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			decorated[pad] = nil
		end
	end)
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
