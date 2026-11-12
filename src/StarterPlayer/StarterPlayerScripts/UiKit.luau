--!strict
-- Shared look of the HUD: one palette, one font and the few widgets every
-- HUD script builds from (outlined text, progress bar, card). Taken from
-- the HUD design: chunky Montserrat with a dark ink outline, cream cards
-- with ink borders, green progress fills. New HUD pieces use these instead
-- of styling their own labels.

local UiKit = {}
local menuChanged = Instance.new("BindableEvent")
UiKit.MenuChanged = menuChanged.Event
UiKit.MenuOpen = false
local panels: { GuiObject } = {}

UiKit.Colors = require(game:GetService("ReplicatedStorage").Shared.Config.Interface).Colors

task.spawn(function()
	local ids = {}
	local function collect(values)
		for _, value in values do
			if type(value) == "table" then collect(value) else table.insert(ids, value) end
		end
	end
	collect(require(game:GetService("ReplicatedStorage").Shared.Config.Interface).Images)
	pcall(function() game:GetService("ContentProvider"):PreloadAsync(ids) end)
end)

UiKit.Font = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
UiKit.FontBold = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)

function UiKit.Corner(parent: Instance, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

function UiKit.Stroke(parent: Instance, thickness: number, color: Color3?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = color or UiKit.Colors.Ink
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	if parent:IsA("GuiObject") and not parent:IsA("TextLabel") then
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	stroke.Parent = parent
	return stroke
end

function UiKit.Shade(parent: GuiObject, color: Color3)
	parent.BackgroundColor3 = Color3.new(1, 1, 1)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.12), color)
	gradient.Rotation = 90
	gradient.Parent = parent
	return gradient
end

-- One visible menu, one input shield. HUD controllers share this state.
function UiKit.OpenPanel(panel: GuiObject)
	for _, other in panels do if other ~= panel then other.Visible = false end end
	panel.Visible = true
end

function UiKit.ManagePanel(panel: GuiObject)
	table.insert(panels, panel)
	local shield = Instance.new("TextButton")
	shield.Name = "MenuBackdrop"; shield.Text = ""; shield.AutoButtonColor = false
	shield.Selectable = false; shield.BackgroundColor3 = UiKit.Colors.Ink
	shield.BackgroundTransparency = 0.35; shield.BorderSizePixel = 0
	shield.Size = UDim2.fromScale(1, 1); shield.ZIndex = 1
	shield.Visible = panel.Visible; shield.Parent = panel.Parent
	panel.ZIndex = 2
	shield.Activated:Connect(function() panel.Visible = false end)
	local function changed()
		shield.Visible = panel.Visible
		local open = false
		for _, other in panels do if other.Parent and other.Visible then open = true; break end end
		UiKit.MenuOpen = open; menuChanged:Fire(open)
	end
	panel:GetPropertyChangedSignal("Visible"):Connect(changed)
	game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
		if panel.Visible and (input.KeyCode == Enum.KeyCode.ButtonB or (not processed and input.KeyCode == Enum.KeyCode.Escape)) then
			panel.Visible = false
			game:GetService("GuiService").SelectedObject = nil
		end
	end)
	changed()
end

-- HUD text that reads on any background: chunky font, dark outline.
-- Sized by the caller; the outline scales with the text size.
function UiKit.OutlinedText(parent: Instance, text: string, textSize: number, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = UiKit.Font
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = color or UiKit.Colors.Cream
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Parent = parent
	UiKit.Stroke(label, math.clamp(math.round(textSize / 9), 2, 5))
	return label
end

export type ProgressBar = {
	Frame: Frame,
	Set: (ratio: number, animate: boolean?) -> (),
}

-- Rounded bar with an ink border. Set(0..1) moves the fill (tweened unless
-- animate is false).
function UiKit.ProgressBar(parent: Instance, size: UDim2, fillColor: Color3?, shadeColor: Color3?): ProgressBar
	local TweenService = game:GetService("TweenService")

	local frame = Instance.new("Frame")
	frame.Size = size
	frame.BackgroundColor3 = UiKit.Colors.Track
	frame.Parent = parent
	UiKit.Corner(frame, 999)
	UiKit.Stroke(frame, 3)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = frame
	UiKit.Corner(fill, 999)
	-- Two-tone fill: a darker band along the bottom edge.
	local top, bottom = fillColor or UiKit.Colors.Green, shadeColor or UiKit.Colors.GreenShade
	local tone = Instance.new("UIGradient")
	tone.Rotation = 90
	tone.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(0.68, top),
		ColorSequenceKeypoint.new(0.7, bottom),
		ColorSequenceKeypoint.new(1, bottom),
	})
	tone.Parent = fill

	local function set(ratio: number, animate: boolean?)
		local goal = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		if animate == false then
			fill.Size = goal
		else
			TweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = goal }):Play()
		end
	end

	return { Frame = frame, Set = set }
end

-- Cream card with an ink border (quest card, badges).
function UiKit.Card(parent: Instance, radius: number?): Frame
	local card = Instance.new("Frame")
	card.BackgroundColor3 = UiKit.Colors.Cream
	card.Parent = parent
	UiKit.Corner(card, radius or 16)
	UiKit.Stroke(card, 3)
	return card
end

function UiKit.Chrome(parent: GuiObject, key: string, sliced: boolean?)
	local images = require(game:GetService("ReplicatedStorage").Shared.Config.Interface).Images.Chrome
	local id = images[key]
	if not id then return end
	parent.BackgroundTransparency = 1
	local stroke = parent:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Enabled = false end
	local art = Instance.new("ImageLabel")
	art.Name = "Chrome"; art.BackgroundTransparency = 1
	art.Image = id; art.Size = UDim2.fromScale(1, 1)
	if sliced then
		art.ScaleType = Enum.ScaleType.Slice
		art.SliceCenter = Rect.new(100, 100, 412, 412)
		art.SliceScale = 0.25
	end
	art.Parent = parent
	-- The art is behind live text, icons and controls in this sibling tree.
	art.ZIndex = 0
end

function UiKit.Icon(parent: Instance, image: string, size: number): ImageLabel
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Image = image
	icon.Size = UDim2.fromOffset(size, size)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = parent
	return icon
end

function UiKit.Text(parent: Instance, value: string, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = UiKit.FontBold
	label.TextColor3 = UiKit.Colors.Ink
	label.TextSize = size; label.Text = value; label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

function UiKit.FitText(label: TextLabel, minimum: number, maximum: number)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = minimum; limit.MaxTextSize = maximum; limit.Parent = label
end

function UiKit.PlainValue(label: TextLabel)
	label.TextColor3 = UiKit.Colors.Ink
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Enabled = false end
end

function UiKit.Button(parent: Instance, name: string, value: string, callback): TextButton
	local item = Instance.new("TextButton")
	item.Name = name; item.Text = value; item.FontFace = UiKit.Font
	item.BackgroundColor3 = UiKit.Colors.Gold
	item.TextColor3 = UiKit.Colors.Ink; item.TextSize = 16
	item.AutoButtonColor = true; item.Selectable = true
	UiKit.Corner(item, 10); UiKit.Stroke(item, 2)
	item.Activated:Connect(function() if item.Active then callback() end end)
	item.Parent = parent
	return item
end

-- Icon and value on the world, rather than a generic box of resource names.
function UiKit.Resource(parent: Instance, name: string, image: string, width: number, iconSize: number, textSize: number?)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(width, iconSize)
	frame.Parent = parent
	local icon = UiKit.Icon(frame, image, iconSize)
	local label = UiKit.OutlinedText(frame, "", textSize or 22)
	label.Name = "Value"
	label.AutomaticSize = Enum.AutomaticSize.None
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Position = UDim2.fromOffset(iconSize + 3, 0)
	label.Size = UDim2.new(1, -iconSize - 3, 1, 0)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = textSize or 22; limit.MinTextSize = 12; limit.Parent = label
	label.TextScaled = true
	return { Frame = frame, Icon = icon, Value = label }
end

function UiKit.NavigationLayout(viewport: Vector2)
	local H = require(game:GetService("ReplicatedStorage").Shared.Config.Interface).Hud
	local compact = viewport.Y < H.CompactHeight
	local cell = if compact then H.CompactNavigationCell else H.NavigationCell
	local top = if compact then H.CompactNavigationTop else math.min(H.NavigationMaxTop, math.max(72, viewport.Y * H.NavigationTop))
	return UDim2.fromOffset(H.Edge, top), Vector2.new(cell.X * 2 + H.NavigationGap, cell.Y * 2 + H.NavigationGap), cell
end

return UiKit
