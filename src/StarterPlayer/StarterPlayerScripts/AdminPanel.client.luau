--!strict
-- Admin test panel, shown only to players the server marks "Admin"
-- (AdminService, Config/Admin). Layout follows the usual public admin
-- panels: a toggle button / key (F2), category tabs and a searchable list.
--   Tools:    every tool with its 3D preview, click = own + equip it
--   Economy:  coins, XP, unlock every island, give all tools, empty bag
--   Teleport: jump to any island's tool stand
--   Player:   fast walk on/off
-- Every button only fires AdminCommand; the server re-checks and applies.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Admin = require(Shared.Config.Admin)
local Tools = require(Shared.Config.Tools)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Format)
local Ui = require(script.Parent:WaitForChild("UiKit"))
local T = Ui.Theme

local player = Players.LocalPlayer

local function waitForAdmin()
	while player:GetAttribute("Admin") ~= true do
		player:GetAttributeChangedSignal("Admin"):Wait()
	end
end
waitForAdmin()

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminCommand") :: RemoteEvent
local function send(command: string, argument: any?)
	remote:FireServer(command, argument)
end

local gui = Ui.LocalGui("AdminPanel", 50)
local window = Ui.Window(gui, "AdminWindow", "Admin", Ui.Images.Coin)
window.SetSubtitle("Test tools: everything here changes only your save. F2 opens and closes.")
window.SetTabs(true)

-- Toggle button, bottom-right above the hotbar.
local current = "Tools"
local show: (string) -> ()
local function open()
	if window.Panel.Visible then
		window.Panel.Visible = false
	else
		Ui.OpenPanel(window.Panel)
		show(current) -- rebuilt on open: tool previews use the art loaded by then
	end
end

local toggle = Ui.Button(gui, "AdminToggle", "ADMIN", open, "Muted")
toggle.AnchorPoint = Vector2.new(1, 1)
toggle.Position = UDim2.new(1, -12, 1, -96)
toggle.Size = UDim2.fromOffset(92, 40)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.F2 then
		open()
	end
end)

local body = window.Body
local function clear()
	for _, child in body:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function grid(order: number, cell: Vector2): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Grid"; frame.BackgroundTransparency = 1
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -4, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Parent = body
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	return frame
end

local function button(parent: Instance, order: number, label: string, callback: () -> (), style: string?): TextButton
	local item = Ui.Button(parent, "Cmd" .. order, label, callback, style)
	item.LayoutOrder = order
	return item
end

local pages: { [string]: () -> () } = {}

pages.Tools = function()
	-- Wait for the tool meshes (ToolArtService) so previews aren't empty.
	local art = ReplicatedStorage:FindFirstChild("ToolArt")
	if art then
		game:GetService("ContentProvider"):PreloadAsync({ art })
	end
	local search = Instance.new("TextBox")
	search.Name = "Search"; search.LayoutOrder = 1
	search.PlaceholderText = "Search tools..."; search.Text = ""
	search.FontFace = Ui.FontBold; search.TextSize = 18; search.TextColor3 = T.Text
	search.BackgroundColor3 = T.Card; search.ClearTextOnFocus = false
	search.Size = UDim2.new(1, -4, 0, 40)
	Ui.Corner(search, 10)
	search.Parent = body
	local list = grid(2, Vector2.new(150, 150))
	local cards: { [string]: GuiObject } = {}
	for i, def in Tools.List do
		local card = Ui.Surface(list, T.Card, T.CardStroke, 12)
		card.Name = def.Id; card.LayoutOrder = i
		local preview = Ui.ToolPreview(card, def.Id)
		preview.Position = UDim2.fromOffset(6, 4); preview.Size = UDim2.new(1, -12, 0, 92)
		local name = Ui.Text(card, def.DisplayName, 14)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.Position = UDim2.fromOffset(4, 96); name.Size = UDim2.new(1, -8, 0, 20)
		Ui.FitText(name, 9, 14)
		local give = Ui.Button(card, "Equip", "EQUIP", function() send("GiveTool", def.Id) end, "Green")
		give.Position = UDim2.new(0, 8, 1, -34); give.Size = UDim2.new(1, -16, 0, 28)
		cards[def.Id] = card
	end
	search:GetPropertyChangedSignal("Text"):Connect(function()
		local query = string.lower(search.Text)
		for _, def in Tools.List do
			cards[def.Id].Visible = query == "" or string.find(string.lower(def.DisplayName), query, 1, true) ~= nil
		end
	end)
end

pages.Economy = function()
	local list = grid(1, Vector2.new(200, 48))
	for i, amount in Admin.Coins do
		button(list, i, "+" .. Format.Number(amount) .. " COINS", function() send("Coins", amount) end, "Green")
	end
	button(list, 10, "+XP (LEVEL UP)", function() send("Xp") end, "Blue")
	button(list, 11, "UNLOCK ALL ISLANDS", function() send("UnlockZones") end, "Blue")
	button(list, 12, "OWN ALL TOOLS", function() send("GiveAllTools") end, "Blue")
	button(list, 13, "EMPTY GRASS BAG", function() send("EmptyBag") end, "Muted")
end

pages.Teleport = function()
	local list = grid(1, Vector2.new(200, 48))
	for i, zone in Zones.List do
		button(list, i, string.upper(zone.DisplayName), function()
			send("Teleport", zone.Id)
			window.Panel.Visible = false
		end, "Blue")
	end
end

pages.Player = function()
	local list = grid(1, Vector2.new(200, 48))
	button(list, 1, "FAST WALK ON/OFF", function() send("FastWalk") end, "Blue")
end

local order = { "Tools", "Economy", "Teleport", "Player" }
local tabs: { [string]: TextButton } = {}
function show(name: string)
	current = name
	clear()
	for tabName, tab in tabs do
		Ui.Paint(tab, if tabName == name then "Blue" else "Muted")
	end
	pages[name]()
end
for i, name in order do
	tabs[name] = Ui.Tab(window.Tabs, name, i, function() show(name) end)
end
