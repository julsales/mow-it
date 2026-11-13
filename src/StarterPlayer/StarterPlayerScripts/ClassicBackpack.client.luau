--!strict
-- Roblox's classic hotbar and backpack, rebuilt so it can match the HUD:
-- same layout and behaviour (numbered slots, 1-9 to hold or put away,
-- ` or + for the backpack, search box), a little bluer, with 3D tool
-- icons (UiKit.ToolPreview) and filters for Tools and Crew. The core
-- backpack is turned off. Tools are the real Roblox Tools that
-- ToolBackpackService puts in the Backpack; holding one equips it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tools = require(Shared.Config.Tools)
local Interface = require(Shared.Config.Interface)
local Rules = require(Shared.ProgressionRules)
local State = require(script.Parent:WaitForChild("ClientState"))
local Ui = require(script.Parent:WaitForChild("UiKit"))
local B, T, Images = Interface.Backpack, Ui.Theme, Ui.Images
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

task.spawn(function()
	for _ = 1, 20 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then return end
		task.wait(0.5)
	end
end)

local ladder: { [string]: number } = {}
for index, def in Tools.List do ladder[def.Id] = index end

type Item = { Key: string, Name: string, Tool: Tool?, ToolId: string?, CrewUid: string?, Rarity: string?, Selected: boolean }

local gui = Ui.LocalGui("ClassicBackpack", 3)
local root = Instance.new("Frame")
root.Name = "Root"; root.BackgroundTransparency = 1
root.AnchorPoint = Vector2.new(0.5, 1); root.Position = UDim2.new(0.5, 0, 1, -B.Bottom)
root.Size = UDim2.fromOffset(B.Inventory.X, B.Inventory.Y + B.Slot + 12)
root.Parent = gui
Ui.AutoScale(gui, root)

local hotbar = Instance.new("Frame")
hotbar.Name = "Hotbar"; hotbar.BackgroundTransparency = 1
hotbar.AnchorPoint = Vector2.new(0.5, 1); hotbar.Position = UDim2.new(0.5, 0, 1, 0)
hotbar.Size = UDim2.new(1, 0, 0, B.Slot)
hotbar.Parent = root
local hotbarLayout = Instance.new("UIListLayout")
hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
hotbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
hotbarLayout.Padding = UDim.new(0, B.Gap); hotbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
hotbarLayout.Parent = hotbar

-- Inventory panel, above the hotbar like the classic one.
local inventory = Instance.new("Frame")
inventory.Name = "Inventory"; inventory.Visible = false
inventory.BackgroundColor3 = T.Surface; inventory.BackgroundTransparency = B.PanelTransparency
inventory.AnchorPoint = Vector2.new(0.5, 1); inventory.Position = UDim2.new(0.5, 0, 1, -B.Slot - 10)
inventory.Size = UDim2.fromOffset(B.Inventory.X, B.Inventory.Y)
inventory.Parent = root
Ui.Corner(inventory, B.Radius)
Ui.Stroke(inventory, 2, T.SurfaceStroke)
local search = Instance.new("TextBox")
search.Name = "Search"; search.PlaceholderText = "Search"; search.Text = ""; search.ClearTextOnFocus = false
search.FontFace = Ui.FontBold; search.TextSize = 15; search.TextColor3 = T.Text; search.PlaceholderColor3 = T.TextMuted
search.TextXAlignment = Enum.TextXAlignment.Left
search.BackgroundColor3 = T.Card; search.BackgroundTransparency = 0
search.Position = UDim2.fromOffset(B.FilterWidth + 20, 10); search.Size = UDim2.new(1, -B.FilterWidth - 30, 0, 32)
search.Parent = inventory
Ui.Corner(search, 6); Ui.Stroke(search, 1.5, T.CardStroke)
local searchPad = Instance.new("UIPadding"); searchPad.PaddingLeft = UDim.new(0, 10); searchPad.Parent = search
local filterRow = Instance.new("Frame")
filterRow.Name = "Filters"; filterRow.BackgroundTransparency = 1
filterRow.Position = UDim2.fromOffset(10, 10); filterRow.Size = UDim2.new(0, B.FilterWidth, 1, -20)
filterRow.Parent = inventory
local filterLayout = Instance.new("UIListLayout")
filterLayout.FillDirection = Enum.FillDirection.Vertical; filterLayout.Padding = UDim.new(0, 8)
filterLayout.SortOrder = Enum.SortOrder.LayoutOrder; filterLayout.Parent = filterRow
local grid = Instance.new("ScrollingFrame")
grid.Name = "Grid"; grid.BackgroundTransparency = 1; grid.BorderSizePixel = 0
grid.Position = UDim2.fromOffset(B.FilterWidth + 20, 52); grid.Size = UDim2.new(1, -B.FilterWidth - 24, 1, -60)
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y; grid.CanvasSize = UDim2.new()
grid.ScrollBarThickness = 4; grid.ScrollBarImageColor3 = B.Selected
grid.Parent = inventory
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(B.Slot, B.Slot); gridLayout.CellPadding = UDim2.fromOffset(B.Gap, B.Gap)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder; gridLayout.Parent = grid

local tooltip = Ui.OutlinedText(root, "", 14)
tooltip.Name = "Tooltip"; tooltip.Visible = false; tooltip.AnchorPoint = Vector2.new(0.5, 1); tooltip.ZIndex = 5

local filter = "All"
local refresh: () -> ()

local function heldTool(): Tool?
	return if player.Character then player.Character:FindFirstChildOfClass("Tool") else nil
end

local function activate(item: Item)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if item.Tool and humanoid then
		if heldTool() == item.Tool then humanoid:UnequipTools() else humanoid:EquipTool(item.Tool) end
	elseif item.CrewUid then
		(remotes:WaitForChild("GameAction") :: RemoteEvent):FireServer("EquipCrew", item.CrewUid)
	end
end

-- One classic slot: dark rounded square, number in the corner, the icon,
-- a cyan rim when held/equipped.
local function slot(parent: Instance, item: Item, number: number?, order: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = item.Key; button.Text = ""; button.LayoutOrder = order; button.AutoButtonColor = true
	button.BackgroundColor3 = B.Fill; button.BackgroundTransparency = B.FillTransparency
	button.Size = UDim2.fromOffset(B.Slot, B.Slot)
	button.Parent = parent
	Ui.Corner(button, B.Radius)
	local rim = Ui.Stroke(button, 1.5, if item.Selected then B.Selected elseif item.Rarity then B.Rarity[item.Rarity] else B.SlotStroke)
	rim.Thickness = if item.Selected then 3 else 1.5
	local icon: GuiObject = if item.ToolId then Ui.ToolPreview(button, item.ToolId) else Ui.Icon(button, Images.Crew, 0)
	icon.Position = UDim2.fromOffset(4, 4); icon.Size = UDim2.new(1, -8, 1, -8)
	if number then
		local key = Ui.Heading(button, tostring(number), 13)
		key.Name = "Key"; key.Position = UDim2.fromOffset(5, 2); key.Size = UDim2.fromOffset(14, 16)
	end
	button.MouseEnter:Connect(function()
		tooltip.Text = item.Name; tooltip.Visible = true
		tooltip.Position = UDim2.fromOffset(button.AbsolutePosition.X - root.AbsolutePosition.X + button.AbsoluteSize.X / 2, button.AbsolutePosition.Y - root.AbsolutePosition.Y - 4)
		local scale = root:FindFirstChildOfClass("UIScale")
		if scale and scale.Scale > 0 then
			tooltip.Position = UDim2.fromOffset(tooltip.Position.X.Offset / scale.Scale, tooltip.Position.Y.Offset / scale.Scale)
		end
	end)
	button.MouseLeave:Connect(function() tooltip.Visible = false end)
	button.Activated:Connect(function() activate(item) end)
	return button
end

local function toolItems(): { Item }
	local items: { Item } = {}
	local held = heldTool()
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		for _, child in if container then container:GetChildren() else {} do
			local id = child:GetAttribute("ToolId")
			if child:IsA("Tool") and type(id) == "string" and ladder[id] then
				table.insert(items, { Key = id, Name = child.Name, Tool = child, ToolId = id, Selected = child == held })
			end
		end
	end
	table.sort(items, function(a, b) return ladder[a.ToolId :: string] < ladder[b.ToolId :: string] end)
	return items
end

local function crewItems(profile): { Item }
	local items: { Item } = {}
	if not profile then return items end
	local uids = {}
	for uid in profile.Crew do table.insert(uids, uid) end
	table.sort(uids, function(a, b) return tonumber(a) < tonumber(b) end)
	for _, uid in uids do
		local def = Rules.CrewDef(profile.Crew[uid].Id)
		if def then
			table.insert(items, { Key = "crew" .. uid, Name = def.DisplayName, CrewUid = uid, Rarity = def.Rarity,
				Selected = table.find(profile.EquippedCrew, uid) ~= nil })
		end
	end
	return items
end

local hotbarItems: { Item } = {}
local filterButtons: { [string]: TextButton } = {}
for index, name in B.Filters do
	local button = Ui.Button(filterRow, name, string.upper(name), function() filter = name; refresh() end, "Muted")
	button.LayoutOrder = index
	button.Size = UDim2.new(1, 0, 0, 40)
	filterButtons[name] = button
end

-- The classic + slot at the end of the hotbar opens the backpack.
local more = Instance.new("TextButton")
more.Name = "Open"; more.Text = "+"; more.FontFace = Ui.Font; more.TextSize = 30; more.TextColor3 = T.Text
more.BackgroundColor3 = B.Fill; more.BackgroundTransparency = B.FillTransparency; more.LayoutOrder = 99
more.Size = UDim2.fromOffset(B.Slot, B.Slot); more.Parent = hotbar
Ui.Corner(more, B.Radius)
local moreRim = Ui.Stroke(more, 1.5, B.SlotStroke)
more.Activated:Connect(function() inventory.Visible = not inventory.Visible; refresh() end)

refresh = function()
	gui.Enabled = not Ui.MenuOpen
	local profile = State.Get()
	local tools = toolItems()
	-- Hotbar: the best tools you own, cheapest to best, keys 1-9.
	hotbarItems = table.move(tools, math.max(1, #tools - B.HotbarSlots + 1), #tools, 1, {})
	for _, child in hotbar:GetChildren() do if child:IsA("TextButton") and child ~= more then child:Destroy() end end
	for index, item in hotbarItems do slot(hotbar, item, index, index) end
	moreRim.Color = if inventory.Visible then B.Selected else B.SlotStroke
	moreRim.Thickness = if inventory.Visible then 3 else 1.5
	more.Text = if inventory.Visible then "–" else "+"
	if not inventory.Visible then return end
	for name, button in filterButtons do
		Ui.Paint(button, if name == filter then "Blue" else "Muted")
	end
	for _, child in grid:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
	local items = {}
	if filter ~= "Crew" then for _, item in tools do table.insert(items, item) end end
	if filter ~= "Tools" then for _, item in crewItems(profile) do table.insert(items, item) end end
	local query = string.lower(search.Text)
	for index, item in items do
		if query == "" or string.find(string.lower(item.Name), query, 1, true) then slot(grid, item, nil, index) end
	end
end

local queued = false
local function queue()
	if queued then return end
	queued = true
	task.defer(function() queued = false; refresh() end)
end
local function watch(container: Instance?)
	if not container then return end
	container.ChildAdded:Connect(queue); container.ChildRemoved:Connect(queue)
end
player.ChildAdded:Connect(function(child) if child:IsA("Backpack") then watch(child); queue() end end)
watch(player:FindFirstChildOfClass("Backpack"))
player.CharacterAdded:Connect(function(character) watch(character); queue() end)
watch(player.Character)
search:GetPropertyChangedSignal("Text"):Connect(queue)
State.Changed:Connect(queue)
Ui.MenuChanged:Connect(queue)

local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
	Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine }
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or Ui.MenuOpen then return end
	local index = table.find(KEYS, input.KeyCode)
	if index and hotbarItems[index] then activate(hotbarItems[index]) end
	if input.KeyCode == Enum.KeyCode.Backquote then inventory.Visible = not inventory.Visible; refresh() end
end)
refresh()
