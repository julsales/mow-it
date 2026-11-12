--!strict
-- Shop: a functional shop/inventory panel for tools and storage. Opened
-- with the "SHOP" button. Every row shows the item, its stats and one
-- button: price (buy) / Equip / Equipped / Zone N (locked).
-- No emoji: the UI fonts render 🪙/🛒/🔒 as empty boxes on some clients.
-- The server validates every purchase (ShopService); buying an owned item
-- just equips it. Placeholder look on purpose: the final HUD art comes
-- from the HUD design, this panel only has to be clear and work on phones.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Tools = require(Shared.Config.Tools)
local Backpacks = require(Shared.Config.Backpacks)
local Zones = require(Shared.Config.Zones)
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local COLORS = {
	Panel = Color3.fromRGB(28, 40, 30),
	Row = Color3.fromRGB(40, 56, 42),
	RowEquipped = Color3.fromRGB(52, 86, 52),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(180, 200, 180),
	Buy = Color3.fromRGB(60, 170, 70),
	CantAfford = Color3.fromRGB(90, 100, 90),
	Equip = Color3.fromRGB(50, 120, 210),
	Equipped = Color3.fromRGB(70, 80, 70),
	Locked = Color3.fromRGB(110, 70, 60),
	Tab = Color3.fromRGB(46, 66, 48),
	TabActive = Color3.fromRGB(240, 180, 40),
}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, text: string, size: number, color: Color3, bold: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color
	l.TextSize = size
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Text = text
	b.BackgroundColor3 = color
	b.TextColor3 = COLORS.Text
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 8)
	-- roblox-ui: TextScaled without bounds gives uneven sizes; keep 14..22 px.
	local size = Instance.new("UITextSizeConstraint")
	size.MinTextSize = 14
	size.MaxTextSize = 22
	size.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = b
	return b
end

-- Layout ------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "ShopGui"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local openButton = button(gui, "SHOP", COLORS.Buy)
openButton.Name = "OpenShop"
openButton.AnchorPoint = Vector2.new(1, 0)
openButton.Position = UDim2.new(1, -10, 0, 60)
openButton.Size = UDim2.new(0, 160, 0, 48)

local panel = Instance.new("Frame")
panel.Name = "Shop"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.9, 0.8)
panel.BackgroundColor3 = COLORS.Panel
panel.Visible = false
panel.Parent = gui
corner(panel, 14)
do
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 640)
	limit.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(240, 180, 40)
	stroke.Parent = panel
end

local title = label(panel, "Shop", 26, COLORS.Text, true)
title.Position = UDim2.new(0, 16, 0, 10)
title.Size = UDim2.new(1, -80, 0, 34)

local closeButton = button(panel, "X", Color3.fromRGB(190, 60, 50))
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -10, 0, 10)
closeButton.Size = UDim2.new(0, 40, 0, 40)

local tabs = Instance.new("Frame")
tabs.BackgroundTransparency = 1
tabs.Position = UDim2.new(0, 12, 0, 54)
tabs.Size = UDim2.new(1, -24, 0, 40)
tabs.Parent = panel
do
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.Parent = tabs
end
local toolsTab = button(tabs, "Tools", COLORS.TabActive)
toolsTab.Size = UDim2.new(0.5, -4, 1, 0)
local packsTab = button(tabs, "Storage", COLORS.Tab)
packsTab.Size = UDim2.new(0.5, -4, 1, 0)

local list = Instance.new("ScrollingFrame")
list.Name = "List"
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Position = UDim2.new(0, 12, 0, 104)
list.Size = UDim2.new(1, -24, 1, -116)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.ScrollBarThickness = 8
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.Parent = panel
do
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = list
end

-- Rows --------------------------------------------------------------------------

type Row = {
	Frame: Frame,
	Action: TextButton,
	Id: string,
	Price: number,
	RequiredZone: number,
}

local function makeRow(index: number, id: string, name: string, stats: string, price: number, requiredZone: number, remoteName: string): Row
	local frame = Instance.new("Frame")
	frame.Name = id
	frame.LayoutOrder = index
	frame.Size = UDim2.new(1, 0, 0, 64)
	frame.BackgroundColor3 = COLORS.Row
	frame.Parent = list
	corner(frame, 10)

	local nameLabel = label(frame, name, 18, COLORS.Text, true)
	nameLabel.Position = UDim2.new(0, 12, 0, 8)
	nameLabel.Size = UDim2.new(1, -150, 0, 24)

	local statsLabel = label(frame, stats, 14, COLORS.Muted)
	statsLabel.Position = UDim2.new(0, 12, 0, 34)
	statsLabel.Size = UDim2.new(1, -150, 0, 20)

	local action = button(frame, "", COLORS.Buy)
	action.AnchorPoint = Vector2.new(1, 0.5)
	action.Position = UDim2.new(1, -8, 0.5, 0)
	action.Size = UDim2.new(0, 128, 0, 46)
	action.Activated:Connect(function()
		(remotes:WaitForChild(remoteName) :: RemoteEvent):FireServer(id)
	end)

	return { Frame = frame, Action = action, Id = id, Price = price, RequiredZone = requiredZone }
end

local toolRows: { Row } = {}
for i, def in Tools.List do
	local stats = ("Power %s · Range %s"):format(Format.Number(def.Power), tostring(def.Radius))
	table.insert(toolRows, makeRow(i, def.Id, def.DisplayName, stats, def.Price, def.RequiredZone, "BuyTool"))
end
local packRows: { Row } = {}
for i, def in Backpacks.List do
	local stats = ("Capacity %s"):format(Format.Number(def.Capacity))
	table.insert(packRows, makeRow(100 + i, def.Id, def.DisplayName, stats, def.Price, def.RequiredZone, "BuyBackpack"))
end

local function paintRows(rows: { Row }, owned: { [string]: boolean }, equipped: string, profile)
	local zone = Zones.HighestUnlockedIndex(profile.UnlockedZoneIds)
	for _, row in rows do
		local action = row.Action
		row.Frame.BackgroundColor3 = if row.Id == equipped then COLORS.RowEquipped else COLORS.Row
		action.Active = true
		if row.Id == equipped then
			action.Text = "Equipped"
			action.BackgroundColor3 = COLORS.Equipped
			action.Active = false
		elseif owned[row.Id] then
			action.Text = "Equip"
			action.BackgroundColor3 = COLORS.Equip
		elseif zone < row.RequiredZone then
			action.Text = "Zone " .. row.RequiredZone
			action.BackgroundColor3 = COLORS.Locked
			action.Active = false
		else
			action.Text = "$ " .. Format.Number(row.Price)
			action.BackgroundColor3 = if profile.Coins >= row.Price then COLORS.Buy else COLORS.CantAfford
		end
	end
end

local showingTools = true

local function refresh()
	local profile = ClientState.Get()
	if not profile then
		return
	end
	paintRows(toolRows, profile.OwnedToolIds, profile.EquippedToolId, profile)
	paintRows(packRows, profile.OwnedBackpackIds, profile.EquippedBackpackId, profile)
	for _, row in toolRows do
		row.Frame.Visible = showingTools
	end
	for _, row in packRows do
		row.Frame.Visible = not showingTools
	end
	toolsTab.BackgroundColor3 = if showingTools then COLORS.TabActive else COLORS.Tab
	packsTab.BackgroundColor3 = if showingTools then COLORS.Tab else COLORS.TabActive
end

toolsTab.Activated:Connect(function()
	showingTools = true
	list.CanvasPosition = Vector2.zero
	refresh()
end)
packsTab.Activated:Connect(function()
	showingTools = false
	list.CanvasPosition = Vector2.zero
	refresh()
end)
openButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
	refresh()
end)
-- Other scripts (shop counters, ShopDisplay.client.luau) open the panel.
local openEvent = Instance.new("BindableEvent")
openEvent.Name = "OpenShop"
openEvent.Event:Connect(function()
	panel.Visible = true
	refresh()
end)
openEvent.Parent = script.Parent
closeButton.Activated:Connect(function()
	panel.Visible = false
end)
ClientState.Changed:Connect(refresh)
refresh()

-- Studio-only: +1M coins to try the mowers without grinding. The server
-- creates this remote only in Studio, so the button never exists live.
if RunService:IsStudio() then
	task.spawn(function()
		local devRemote = remotes:WaitForChild("DevGiveCoins", 10) :: RemoteEvent?
		if not devRemote then
			return
		end
		local dev = button(gui, "+$1M (Studio)", Color3.fromRGB(150, 70, 200))
		dev.AnchorPoint = Vector2.new(1, 0)
		dev.Position = UDim2.new(1, -10, 0, 114)
		dev.Size = UDim2.new(0, 160, 0, 40)
		dev.Activated:Connect(function()
			devRemote:FireServer()
		end)
	end)
end
