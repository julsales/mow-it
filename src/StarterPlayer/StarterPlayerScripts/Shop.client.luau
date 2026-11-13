--!strict
-- Physical equipment shop/inventory. Opened at map stalls. Each row has one
-- button: price (buy) / Equip / Equipped / Zone N (locked).
-- No emoji: the UI fonts render 🪙/🛒/🔒 as empty boxes on some clients.
-- The server validates every purchase (ShopService); buying an owned item
-- just equips it. Same window as the HUD menus (UiKit.Window).

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
local T = UiKit.Theme

local gui = UiKit.LocalGui("ShopGui", 5)
local window = UiKit.Window(gui, "Shop", "EQUIPMENT", UiKit.Images.Coins)
local panel, list = window.Panel, window.Body
window.SetSubtitle("Tools, storage and automation for your crew.")
window.SetTabs(true)

-- Rows --------------------------------------------------------------------------

type Row = {
	Frame: Frame,
	Action: TextButton,
	Id: string,
	Price: number,
	RequiredZone: number,
}

-- Name and stats on the left, one action on the right.
local function makeRow(index: number, id: string, name: string, stats: string, price: number, requiredZone: number, remoteName: string): Row
	local frame = UiKit.Surface(list, T.Card, T.CardStroke, 14)
	frame.Name = id
	frame.LayoutOrder = index
	frame.Size = UDim2.new(1, -4, 0, 72)
	local nameLabel = UiKit.Heading(frame, name, 19)
	nameLabel.Position = UDim2.fromOffset(16, 10); nameLabel.Size = UDim2.new(1, -190, 0, 26)
	UiKit.FitText(nameLabel, 13, 19)
	local statsLabel = UiKit.Text(frame, stats, 14, T.TextMuted)
	statsLabel.Position = UDim2.fromOffset(16, 38); statsLabel.Size = UDim2.new(1, -190, 0, 24)
	UiKit.FitText(statsLabel, 11, 14)
	local action = UiKit.Button(frame, "Action", "", function()
		(remotes:WaitForChild(remoteName) :: RemoteEvent):FireServer(id)
	end, "Green")
	action.AnchorPoint = Vector2.new(1, 0.5)
	action.Position = UDim2.new(1, -14, 0.5, 0)
	action.Size = UDim2.fromOffset(156, 44)
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
local buffRows: { Row } = {}
for i, def in Buffs.List do
	table.insert(buffRows, makeRow(200 + i, def.Id, def.DisplayName, def.Description, def.Price, def.RequiredZone, "BuyBuff"))
end

local function paintRows(rows: { Row }, owned: { [string]: boolean }, equipped: string, profile)
	local zone = Zones.HighestUnlockedIndex(profile.UnlockedZoneIds)
	for _, row in rows do
		local action = row.Action
		local stroke = row.Frame:FindFirstChildOfClass("UIStroke") :: UIStroke
		stroke.Color = if row.Id == equipped then T.TileActiveStroke else T.CardStroke
		if row.Id == equipped then
			UiKit.Paint(action, "Progress", "EQUIPPED", false)
		elseif owned[row.Id] then
			UiKit.Paint(action, "Blue", "EQUIP")
		elseif zone < row.RequiredZone then
			UiKit.Paint(action, "Disabled", "ZONE " .. row.RequiredZone)
		else
			UiKit.Paint(action, "Green", Format.Number(row.Price) .. " COINS", profile.Coins >= row.Price)
			if profile.Coins < row.Price then UiKit.Paint(action, "Disabled", Format.Number(row.Price) .. " COINS") end
		end
	end
end

local showing = "Tools"
local refresh: () -> ()
local tabs: { [string]: TextButton } = {}
for index, name in { "Tools", "Storage", "Automation" } do
	tabs[name] = UiKit.Tab(window.Tabs, name, index, function()
		showing = name
		list.CanvasPosition = Vector2.zero
		refresh()
	end)
end

refresh = function()
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
		local available = count < def.MaxStacks and Zones.HighestUnlockedIndex(profile.UnlockedZoneIds) >= row.RequiredZone and profile.Coins >= row.Price
		UiKit.Paint(row.Action, if available then "Green" else "Disabled",
			if count >= def.MaxStacks then "MAXED" else Format.Number(row.Price) .. " (" .. count .. "/" .. def.MaxStacks .. ")")
	end
	for name, tab in tabs do
		UiKit.Paint(tab, if name == showing then "Blue" else "Muted")
	end
end

-- Other scripts (shop counters, ShopDisplay.client.luau) open the panel.
local openEvent = Instance.new("BindableEvent")
openEvent.Name = "OpenShop"
openEvent.Event:Connect(function()
	local operations = player.PlayerGui:FindFirstChild("Operations")
	local other = operations and operations:FindFirstChild("Panel")
	if other and other:IsA("GuiObject") then other.Visible = false end
	UiKit.OpenPanel(panel)
	refresh()
end)
openEvent.Parent = script.Parent
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
		-- A row of its own at the end of the list keeps it off the header.
		local dev = UiKit.Button(list, "DevCoins", "+1M COINS (STUDIO)", function() devRemote:FireServer() end, "Muted")
		dev.LayoutOrder = 999
		dev.Size = UDim2.new(1, -4, 0, 44)
	end)
end
