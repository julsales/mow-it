--!strict
-- Physical equipment shop/inventory. Opened at map stalls. Each row has one
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
local Buffs = require(Shared.Config.Buffs)
local Zones = require(Shared.Config.Zones)
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local UiKit = require(script.Parent:WaitForChild("UiKit"))
local C = UiKit.Colors
local COLORS = {
	Panel = C.Cream, Row = C.Track, RowEquipped = C.Leaf, Text = C.Ink,
	Muted = C.Blue, Buy = C.Gold, CantAfford = C.CreamShade, Equip = C.Green,
	Equipped = C.CreamShade, Locked = C.Coral, Tab = C.Track, TabActive = C.Gold,
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
	l.FontFace = if bold then UiKit.Font else UiKit.FontBold
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
	b.FontFace = UiKit.Font
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
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local openButton = button(gui, "SHOP", COLORS.Buy)
openButton.Name = "OpenShop"
openButton.Visible = false
openButton.AnchorPoint = Vector2.new(0, 0)
openButton.Position = UDim2.new(0, 12, 0, 110)
openButton.Size = UDim2.new(0, 88, 0, 44)

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
	stroke.Color = C.Ink
	stroke.Parent = panel
end

local title = label(panel, "EQUIPMENT", 26, COLORS.Text, true)
title.Position = UDim2.new(0, 70, 0, 10)
title.Size = UDim2.new(1, -130, 0, 34)
UiKit.FitText(title, 18, 26)

local shopIcon = Instance.new("ImageLabel")
shopIcon.BackgroundTransparency = 1
shopIcon.Image = require(Shared.Config.Interface).Images.Shop
shopIcon.Position = UDim2.fromOffset(10, 4)
shopIcon.Size = UDim2.fromOffset(52, 52)
shopIcon.Parent = panel
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

local showing = "Tools"
local buffRows = {}
for i, def in Buffs.List do
	table.insert(buffRows, makeRow(200 + i, def.Id, def.DisplayName, def.Description, def.Price, def.RequiredZone, "BuyBuff"))
end
local buffsTab = button(tabs, "Automation", COLORS.Tab)
buffsTab.Size = UDim2.new(1 / 3, -4, 1, 0)
buffsTab.Position = UDim2.fromScale(2 / 3, 0)
toolsTab.Size = UDim2.new(1 / 3, -4, 1, 0)
packsTab.Size = UDim2.new(1 / 3, -4, 1, 0)
packsTab.Position = UDim2.fromScale(1 / 3, 0)

local function refresh()
	local profile = ClientState.Get()
	if not profile then
		return
	end
	paintRows(toolRows, profile.OwnedToolIds, profile.EquippedToolId, profile)
	paintRows(packRows, profile.OwnedBackpackIds, profile.EquippedBackpackId, profile)
	for _, row in toolRows do
		row.Frame.Visible = showing == "Tools"
	end
	for _, row in packRows do
		row.Frame.Visible = showing == "Storage"
	end
	for _, row in buffRows do
		local def = Buffs.ById[row.Id]
		local count = profile.BuffStacks[row.Id] or 0
		row.Frame.Visible = showing == "Automation"
		row.Action.Text = if count >= def.MaxStacks then "Maxed" else "$ " .. Format.Number(row.Price) .. " (" .. count .. "/" .. def.MaxStacks .. ")"
		row.Action.Active = count < def.MaxStacks and Zones.HighestUnlockedIndex(profile.UnlockedZoneIds) >= row.RequiredZone and profile.Coins >= row.Price
		row.Action.BackgroundColor3 = if row.Action.Active then COLORS.Buy else COLORS.CantAfford
	end
	buffsTab.BackgroundColor3 = if showing == "Automation" then COLORS.TabActive else COLORS.Tab
	toolsTab.BackgroundColor3 = if showing == "Tools" then COLORS.TabActive else COLORS.Tab
	packsTab.BackgroundColor3 = if showing == "Storage" then COLORS.TabActive else COLORS.Tab
end

toolsTab.Activated:Connect(function()
	showing = "Tools"
	list.CanvasPosition = Vector2.zero
	refresh()
end)
packsTab.Activated:Connect(function()
	showing = "Storage"
	list.CanvasPosition = Vector2.zero
	refresh()
end)
buffsTab.Activated:Connect(function() showing = "Automation"; list.CanvasPosition = Vector2.zero; refresh() end)
UiKit.ManagePanel(panel)
openButton.Activated:Connect(function()
	local operations = player.PlayerGui:FindFirstChild("Operations")
	local other = operations and operations:FindFirstChild("Panel")
	if other and other:IsA("GuiObject") then other.Visible = false end
	if panel.Visible then panel.Visible = false else UiKit.OpenPanel(panel) end
	refresh()
end)
-- Other scripts (shop counters, ShopDisplay.client.luau) open the panel.
local openEvent = Instance.new("BindableEvent")
openEvent.Name = "OpenShop"
openEvent.Event:Connect(function()
	UiKit.OpenPanel(panel)
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
		local dev = button(panel, "+$1M (Studio)", C.Blue)
		dev.AnchorPoint = Vector2.new(1, 0)
		dev.Position = UDim2.new(1, -14, 0, 108)
		dev.Size = UDim2.new(0, 144, 0, 44)
		-- A dedicated content row keeps the Studio helper off the HUD/header.
		list.Position = UDim2.fromOffset(12, 164)
		list.Size = UDim2.new(1, -24, 1, -176)
		dev.Activated:Connect(function()
			devRemote:FireServer()
		end)
	end)
end
