--!strict
-- Shared look of the screen UI, built from the OpenPencil boards in
-- docs/art/generated-v3 (mow-it-ui-v3.fig): dark teal glass windows with a
-- cyan rim, a blue header bar, glossy buttons with a navy outline, and the
-- generated glossy icons. Every HUD script builds from these widgets; none
-- styles its own frames. Numbers and colors live in Shared/Config/Interface.

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Interface = require(game:GetService("ReplicatedStorage").Shared.Config.Interface)

local UiKit = {}
local menuChanged = Instance.new("BindableEvent")
UiKit.MenuChanged = menuChanged.Event
UiKit.MenuOpen = false
local panels: { GuiObject } = {}

UiKit.Colors = Interface.Colors
UiKit.Theme = Interface.Theme
UiKit.Images = Interface.Images
UiKit.Hud = Interface.Hud
local T = Interface.Theme
local H = Interface.Hud

task.spawn(function()
	local ids = {}
	local function collect(values)
		for _, value in values do
			if type(value) == "table" then collect(value) elseif value ~= "" then table.insert(ids, value) end
		end
	end
	collect(Interface.Images)
	pcall(function() game:GetService("ContentProvider"):PreloadAsync(ids) end)
end)

local MONTSERRAT = "rbxasset://fonts/families/Montserrat.json"
UiKit.Font = Font.new(MONTSERRAT, Enum.FontWeight.ExtraBold)
UiKit.FontBold = Font.new(MONTSERRAT, Enum.FontWeight.Bold)
UiKit.FontSemi = Font.new(MONTSERRAT, Enum.FontWeight.SemiBold)

function UiKit.Corner(parent: Instance, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

function UiKit.Stroke(parent: Instance, thickness: number, color: Color3?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = color or T.Outline
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	if parent:IsA("GuiObject") and not parent:IsA("TextLabel") then
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	stroke.Parent = parent
	return stroke
end

-- Rounded flat panel with a thin rim (pills, cards, tiles, headers).
function UiKit.Surface(parent: Instance, color: Color3?, stroke: Color3?, radius: number?, thickness: number?): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = color or T.Surface
	frame.BorderSizePixel = 0
	frame.Parent = parent
	UiKit.Corner(frame, radius or 16)
	if stroke then UiKit.Stroke(frame, thickness or 1.5, stroke) end
	return frame
end

-- Quest/offline cards: the board's dark card with a cyan-teal rim.
function UiKit.Card(parent: Instance, radius: number?): Frame
	return UiKit.Surface(parent, T.Surface, T.SurfaceStroke, radius or 16)
end

-- Uploaded art, or nothing while the ID is still missing.
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

-- A generated skin clipped to rounded corners. Tint multiplies the art
-- (OpenPencil MULTIPLY blend on the boards). Without uploaded art the
-- clip shows its own fill, so the widget still reads correctly.
function UiKit.Skin(parent: Instance, image: string, fill: Color3, radius: number, tint: Color3?, scale: Enum.ScaleType?): CanvasGroup
	local clip = Instance.new("CanvasGroup")
	clip.Name = "Skin"
	clip.BackgroundColor3 = fill
	clip.BorderSizePixel = 0
	clip.Size = UDim2.fromScale(1, 1)
	clip.Parent = parent
	UiKit.Corner(clip, radius)
	local art = Instance.new("ImageLabel")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.Image = image
	art.ImageColor3 = tint or Color3.new(1, 1, 1)
	art.ScaleType = scale or Enum.ScaleType.Crop
	art.Size = UDim2.fromScale(1, 1)
	art.Parent = clip
	return clip
end

-- Soft light rays behind a featured icon (rays.png at low opacity).
function UiKit.Rays(parent: Instance, transparency: number): ImageLabel
	local rays = UiKit.Icon(parent, Interface.Images.Rays, 0)
	rays.Name = "Rays"
	rays.ImageTransparency = transparency
	rays.ScaleType = Enum.ScaleType.Crop
	return rays
end

-- Red "!" telling the player a quest is waiting.
function UiKit.AlertBadge(parent: Instance): ImageLabel
	local badge = UiKit.Icon(parent, Interface.Images.QuestAvailable, 0)
	badge.Name = "Alert"
	badge.Size = UDim2.fromOffset(H.Badge.X, H.Badge.Y)
	badge.ScaleType = Enum.ScaleType.Crop
	badge.ZIndex = 4
	if Interface.Images.QuestAvailable == "" then
		badge.BackgroundTransparency = 0
		badge.BackgroundColor3 = T.Badge
		UiKit.Corner(badge, 8)
	end
	return badge
end

function UiKit.Text(parent: Instance, value: string, size: number, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = UiKit.FontBold
	label.TextColor3 = color or T.Text
	label.TextSize = size; label.Text = value; label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

-- Big headings: same text, heavier weight.
function UiKit.Heading(parent: Instance, value: string, size: number, color: Color3?): TextLabel
	local label = UiKit.Text(parent, value, size, color)
	label.FontFace = UiKit.Font
	return label
end

-- Text over the 3D world (level bar, notifications): white with a dark rim.
function UiKit.OutlinedText(parent: Instance, text: string, textSize: number, color: Color3?): TextLabel
	local label = UiKit.Heading(parent, text, textSize, color)
	label.TextWrapped = false
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.AutomaticSize = Enum.AutomaticSize.XY
	UiKit.Stroke(label, math.clamp(math.round(textSize / 9), 2, 5), T.TextDark)
	return label
end

function UiKit.FitText(label: TextLabel, minimum: number, maximum: number)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.TextScaled = true
	local limit = label:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	limit.MinTextSize = minimum; limit.MaxTextSize = maximum; limit.Parent = label
end

-- Glossy button: style fill, navy outline, light strip along the top.
-- Paint() swaps style/text later; inactive buttons ignore clicks.
function UiKit.Paint(item: TextButton, style: string, value: string?, active: boolean?)
	local look = T.Buttons[style]
	item.BackgroundColor3 = look.Fill
	item.TextColor3 = look.Text
	if value then item.Text = value end
	local enabled = if active == nil then not look.Flat else active
	item.Active = enabled; item.Selectable = enabled; item.AutoButtonColor = enabled
	local stroke = item:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Enabled = not look.Flat end
	local gloss = item:FindFirstChild("Gloss")
	if gloss then (gloss :: Frame).Visible = not look.Flat end
end

function UiKit.Button(parent: Instance, name: string, value: string, callback: () -> (), style: string?): TextButton
	local item = Instance.new("TextButton")
	item.Name = name; item.Text = value; item.FontFace = UiKit.Font
	item.TextSize = 16; item.TextWrapped = true
	item.Size = UDim2.new(1, 0, 0, H.ButtonHeight)
	UiKit.Corner(item, 12); UiKit.Stroke(item, 1.5, T.Outline)
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"; gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = T.Gloss; gloss.BorderSizePixel = 0
	gloss.Position = UDim2.fromOffset(4, 3); gloss.Size = UDim2.new(1, -8, 0, 6)
	gloss.Parent = item
	UiKit.Corner(gloss, 4)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 11; limit.MaxTextSize = 16; limit.Parent = item
	item.TextScaled = true
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 6); pad.PaddingBottom = UDim.new(0, 4); pad.Parent = item
	UiKit.Paint(item, style or "Blue")
	item.Activated:Connect(function() if item.Active then callback() end end)
	item.Parent = parent
	return item
end

export type ProgressBar = {
	Frame: Frame,
	Set: (ratio: number, animate: boolean?) -> (),
}

-- Rounded dark track with a bright green fill. Set(0..1) moves the fill
-- (tweened unless animate is false).
function UiKit.ProgressBar(parent: Instance, size: UDim2): ProgressBar
	local frame = UiKit.Surface(parent, T.Track, nil, 999)
	frame.Size = size
	local fill = UiKit.Surface(frame, T.Fill, nil, 999)
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
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

export type Pill = { Frame: Frame, Icon: ImageLabel, Value: TextLabel }

-- HUD readout: dark pill with a cyan rim, a big icon overlapping its left
-- end and a chunky value (coins, clovers, weather, fuel, storage).
function UiKit.Pill(parent: Instance, name: string, image: string, size: Vector2, iconSize: number, textSize: number, color: Color3?): Pill
	local frame = UiKit.Surface(parent, T.Surface, T.SurfaceStroke, math.round(size.Y / 4))
	frame.Name = name
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	local icon = UiKit.Icon(frame, image, iconSize)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	local overhang = math.round((iconSize - size.Y) * 0.75)
	icon.Position = UDim2.new(0, -overhang, 0.5, 0)
	local value = UiKit.Heading(frame, "", textSize, color)
	value.Name = "Value"
	value.TextWrapped = false
	local left = iconSize - overhang + 8
	value.Position = UDim2.fromOffset(left, 0)
	value.Size = UDim2.new(1, -left - 10, 1, 0)
	UiKit.FitText(value, 12, textSize)
	return { Frame = frame, Icon = icon, Value = value }
end

-- Square menu tile: tinted silver button-base, icon, dark name plate.
function UiKit.NavTile(parent: Instance, def, callback: () -> ()): TextButton
	local tile = Instance.new("TextButton")
	tile.Name = def.Page; tile.Text = ""; tile.BackgroundTransparency = 1
	tile.Size = UDim2.fromOffset(H.Tile, H.Tile)
	tile.Selectable = true; tile.AutoButtonColor = false
	tile.Parent = parent
	local inset = math.round(H.Tile * 0.11)
	local face = UiKit.Skin(tile, Interface.Images.Button, def.Tint, math.round(H.Tile * 0.16), def.Tint, Enum.ScaleType.Fit)
	face.Name = "Face"
	face.Position = UDim2.fromOffset(inset, inset); face.Size = UDim2.new(1, -inset * 2, 1, -inset * 2)
	local art = face:FindFirstChild("Art") :: ImageLabel
	art.Position = UDim2.fromOffset(-inset, -inset); art.Size = UDim2.fromOffset(H.Tile, H.Tile)
	if Interface.Images.Button ~= "" then
		face.BackgroundTransparency = 1
		local rim = UiKit.Icon(tile, Interface.Images.Button, H.Tile)
		rim.Name = "Rim"; rim.ZIndex = 0
	else
		UiKit.Stroke(face, 2, Color3.new(1, 1, 1))
	end
	local icon = UiKit.Icon(tile, Interface.Images[def.Icon], H.TileIcon)
	icon.AnchorPoint = Vector2.new(0.5, 0); icon.Position = UDim2.new(0.5, 0, 0, 2)
	local plate = UiKit.Surface(tile, T.Surface, nil, 8)
	plate.Name = "Plate"
	plate.AnchorPoint = Vector2.new(0.5, 1); plate.Position = UDim2.new(0.5, 0, 1, -4)
	plate.Size = UDim2.fromOffset(H.TilePlate.X, H.TilePlate.Y)
	local label = UiKit.Heading(plate, def.Label, 15)
	label.TextXAlignment = Enum.TextXAlignment.Center; label.TextWrapped = false
	label.Size = UDim2.fromScale(1, 1)
	UiKit.FitText(label, 10, 15)
	tile.Activated:Connect(callback)
	local scale = Instance.new("UIScale")
	scale.Parent = tile
	tile.MouseEnter:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.05 }):Play() end)
	tile.MouseLeave:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play() end)
	return tile
end

-- 3D thumbnail of a tool (ToolModels), framed on its longest side so long
-- handles and wide mowers both fill the slot (hotbar, backpack).
function UiKit.ToolPreview(parent: Instance, toolId: string): ViewportFrame
	local ToolModels = require(game:GetService("ReplicatedStorage").Shared.ToolModels)
	local view = Instance.new("ViewportFrame")
	view.Name = "Preview"; view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(200, 200, 200); view.LightDirection = Vector3.new(-1, -1, -1)
	view.Parent = parent
	local model = ToolModels.Build(toolId)
	model.Parent = view
	local camera = Instance.new("Camera")
	local cf, size = model:GetBoundingBox()
	local radius = math.max(size.X, size.Y, size.Z) / 2
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(1, 0.7, 1).Unit * radius * 2.7, cf.Position)
	camera.Parent = view
	view.CurrentCamera = camera
	return view
end

-- Screen-height scale for HUD pieces sized in board pixels.
function UiKit.HudScale(viewport: Vector2): number
	return math.clamp(viewport.Y / H.DesignHeight, H.MinScale, 1)
end

-- Phones in landscape: the HUD switches to its compact arrangement.
function UiKit.IsCompact(viewport: Vector2): boolean
	return viewport.Y < H.CompactHeight
end

-- Width in board pixels: AbsoluteSize without the UIScales above it.
function UiKit.LocalWidth(object: GuiObject): number
	local width = object.AbsoluteSize.X
	local node: Instance? = object
	while node do
		local scale = node:FindFirstChildOfClass("UIScale")
		if scale and scale.Scale > 0 then width /= scale.Scale end
		node = node.Parent
	end
	return width
end

-- Keeps a UIScale on `target` matched to its ScreenGui's height.
function UiKit.AutoScale(gui: LayerCollector, target: GuiObject, onChange: ((number) -> ())?): UIScale
	local scale = Instance.new("UIScale")
	scale.Parent = target
	local function fit()
		scale.Scale = UiKit.HudScale(gui.AbsoluteSize)
		if onChange then onChange(scale.Scale) end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	return scale
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
	shield.Selectable = false; shield.BackgroundColor3 = T.Backdrop
	shield.BackgroundTransparency = 0.45; shield.BorderSizePixel = 0
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
	UserInputService.InputBegan:Connect(function(input, processed)
		if panel.Visible and (input.KeyCode == Enum.KeyCode.ButtonB or (not processed and input.KeyCode == Enum.KeyCode.Escape)) then
			panel.Visible = false
			GuiService.SelectedObject = nil
		end
	end)
	changed()
end

export type Window = {
	Panel: Frame,
	Title: TextLabel,
	Icon: ImageLabel,
	Close: TextButton,
	Subtitle: TextLabel,
	Tabs: Frame,
	Body: ScrollingFrame,
	SetSubtitle: (text: string) -> (),
	SetTabs: (visible: boolean) -> (),
}

-- The boards' modal: generated window frame (9-slice), blue header bar
-- with the page icon breaking out on the left, red close button, an
-- optional subtitle and tab row, then a scrolling body.
function UiKit.Window(gui: LayerCollector, name: string, title: string, icon: string): Window
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundTransparency = 1
	panel.Visible = false
	panel.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Interface.PanelMaxSize; limit.Parent = panel
	UiKit.AutoScale(gui, panel, function(scale)
		panel.Size = UDim2.fromScale(0.94 / scale, 0.92 / scale)
	end)
	local frame = Instance.new("ImageLabel")
	frame.Name = "Frame"
	frame.Image = Interface.Images.Window
	frame.ScaleType = Enum.ScaleType.Slice
	frame.SliceCenter = Interface.Slices.Window
	frame.SliceScale = 0.6
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = T.Surface
	frame.BackgroundTransparency = if Interface.Images.Window == "" then 0 else 1
	frame.Parent = panel
	if Interface.Images.Window == "" then UiKit.Corner(frame, 20); UiKit.Stroke(frame, 3, T.SurfaceStroke) end

	local inset = H.WindowInset
	local header = UiKit.Surface(panel, T.Header, T.HeaderStroke, 13)
	header.Name = "Header"
	header.Position = UDim2.fromOffset(inset, inset)
	header.Size = UDim2.new(1, -inset * 2, 0, H.HeaderHeight)
	local badge = UiKit.Icon(panel, icon, H.HeaderIcon)
	badge.Name = "HeaderIcon"; badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.fromOffset(inset - 8, inset + H.HeaderHeight / 2)
	local heading = UiKit.Heading(header, title, 34)
	heading.Name = "Title"; heading.TextWrapped = false
	heading.Position = UDim2.fromOffset(H.HeaderIcon + 4, 0)
	heading.Size = UDim2.new(1, -H.HeaderIcon - 64, 1, 0)
	UiKit.FitText(heading, 18, 34)
	local close = UiKit.Button(header, "Close", "X", function()
		panel.Visible = false; GuiService.SelectedObject = nil
	end, "Close")
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -11, 0.5, 0)
	close.Size = UDim2.fromOffset(42, 44)

	local top = inset + H.HeaderHeight + 10
	local subtitle = UiKit.Text(panel, "", 17)
	subtitle.Name = "Subtitle"; subtitle.FontFace = UiKit.FontSemi
	subtitle.Position = UDim2.fromOffset(inset + 18, top)
	subtitle.Size = UDim2.new(1, -inset * 2 - 36, 0, 24)
	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"; tabs.BackgroundTransparency = 1
	tabs.Size = UDim2.new(1, -inset * 2 - 24, 0, 40)
	tabs.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 8); tabLayout.Parent = tabs

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1; body.BorderSizePixel = 0
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y; body.CanvasSize = UDim2.new()
	body.ScrollBarThickness = 6; body.ScrollBarImageColor3 = T.SurfaceStroke
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 12); layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center; layout.Parent = body
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 4); padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 4); padding.PaddingBottom = UDim.new(0, 12); padding.Parent = body

	local hasSubtitle, hasTabs = false, false
	local function arrange()
		local y = top + (if hasSubtitle then 32 else 0)
		subtitle.Visible = hasSubtitle
		tabs.Visible = hasTabs
		tabs.Position = UDim2.fromOffset(inset + 14, y)
		y += if hasTabs then 50 else 0
		body.Position = UDim2.fromOffset(inset + 14, y)
		body.Size = UDim2.new(1, -inset * 2 - 20, 1, -y - inset - 6)
	end
	arrange()
	UiKit.ManagePanel(panel)
	return {
		Panel = panel, Title = heading, Icon = badge, Close = close,
		Subtitle = subtitle, Tabs = tabs, Body = body,
		SetSubtitle = function(text: string) subtitle.Text = text; hasSubtitle = text ~= ""; arrange() end,
		SetTabs = function(visible: boolean) hasTabs = visible; arrange() end,
	}
end

-- One full-width row card in a window body: title, detail and an optional
-- action button (Crew, Market, Garden, Franchise, equipment).
function UiKit.Row(parent: Instance, order: number, title: string, detail: string, action: string?, callback: (() -> ())?, style: string?): Frame
	local frame = UiKit.Surface(parent, T.Card, T.CardStroke, 14)
	frame.Name = "Row" .. order
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -4, 0, if action then 128 else 80)
	local name = UiKit.Heading(frame, title, 19)
	name.Name = "Title"
	name.Position = UDim2.fromOffset(16, 10); name.Size = UDim2.new(1, -32, 0, 26)
	UiKit.FitText(name, 13, 19)
	local text = UiKit.Text(frame, detail, 15, T.TextMuted)
	text.Name = "Detail"; text.TextYAlignment = Enum.TextYAlignment.Top
	text.Position = UDim2.fromOffset(16, 38); text.Size = UDim2.new(1, -32, 0, 36)
	if action then
		local item = UiKit.Button(frame, "Action", action, callback or function() end, style)
		item.Position = UDim2.new(0, 16, 1, -54); item.Size = UDim2.new(1, -32, 0, H.ButtonHeight)
	end
	return frame
end

-- Tab buttons for a window's tab row: active Blue, idle Muted.
function UiKit.Tab(parent: Instance, name: string, order: number, callback: () -> ()): TextButton
	local tab = UiKit.Button(parent, name, string.upper(name), callback, "Muted")
	tab.LayoutOrder = order
	tab.Size = UDim2.fromOffset(150, 40)
	return tab
end

function UiKit.LocalGui(name: string, order: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order or 0
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

return UiKit
