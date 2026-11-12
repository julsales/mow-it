--!strict
-- Shared look of the HUD: one palette, one font and the few widgets every
-- HUD script builds from (outlined text, progress bar, card). Taken from
-- the HUD design: chunky Montserrat with a dark ink outline, cream cards
-- with ink borders, green progress fills. New HUD pieces use these instead
-- of styling their own labels.

local UiKit = {}

UiKit.Colors = {
	Ink = Color3.fromRGB(42, 32, 24), -- outlines and borders
	Cream = Color3.fromRGB(251, 243, 223), -- main text, card background
	CreamShade = Color3.fromRGB(217, 199, 154), -- card bottom edge
	Track = Color3.fromRGB(228, 214, 174), -- empty progress bar
	Green = Color3.fromRGB(111, 175, 74), -- progress fill
	GreenShade = Color3.fromRGB(76, 133, 48),
	Leaf = Color3.fromRGB(183, 224, 140), -- positive numbers (+12)
	Gold = Color3.fromRGB(242, 199, 92), -- coins, celebrations
	Coral = Color3.fromRGB(233, 128, 93), -- warnings (bag full)
	Blue = Color3.fromRGB(63, 106, 151), -- card labels
}

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
	stroke.Parent = parent
	return stroke
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

return UiKit
