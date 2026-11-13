--!strict
-- Tool hotbar, bottom center, like Roblox's own: numbered slots with the
-- best owned tools (3D preview, equipped one in green) and a + slot that
-- opens the Backpack (every collectible, filtered). Click or press 1-6 to
-- equip, B or + for the Backpack; the server equips through BuyTool.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tools = require(Shared.Config.Tools)
local State = require(script.Parent:WaitForChild("ClientState"))
local Ui = require(script.Parent:WaitForChild("UiKit"))
local Backpack = require(script.Parent:WaitForChild("Backpack"))
local T, H = Ui.Theme, Ui.Hud
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local gui = Ui.LocalGui("Hotbar", 1)
local bar = Instance.new("Frame")
bar.Name = "Bar"; bar.BackgroundTransparency = 1
bar.AnchorPoint = Vector2.new(0.5, 1); bar.Position = UDim2.new(0.5, 0, 1, -H.Edge)
bar.Size = UDim2.fromOffset((H.HotbarSlots + 1) * (H.HotbarCell + H.HotbarGap), H.HotbarCell + 30)
bar.Parent = gui
Ui.AutoScale(gui, bar)
local row = Instance.new("UIListLayout")
row.FillDirection = Enum.FillDirection.Horizontal
row.HorizontalAlignment = Enum.HorizontalAlignment.Center
row.VerticalAlignment = Enum.VerticalAlignment.Bottom
row.Padding = UDim.new(0, H.HotbarGap); row.SortOrder = Enum.SortOrder.LayoutOrder
row.Parent = bar

-- Name of the equipped tool above the bar.
local name = Ui.OutlinedText(gui, "", 16)
name.Name = "Equipped"; name.AnchorPoint = Vector2.new(0.5, 1)

local function equip(id: string)
	(remotes:WaitForChild("BuyTool") :: RemoteEvent):FireServer(id)
end

-- Best owned tools (ladder order), always including the equipped one.
local function shown(profile): { string }
	local owned = {}
	for _, def in Tools.List do
		if profile.OwnedToolIds[def.Id] then table.insert(owned, def.Id) end
	end
	local first = math.max(1, #owned - H.HotbarSlots + 1)
	local ids = table.move(owned, first, #owned, 1, {})
	local equipped = table.find(owned, profile.EquippedToolId)
	if equipped and equipped < first then
		table.remove(ids, 1)
		table.insert(ids, 1, profile.EquippedToolId)
	end
	return ids
end

local slots: { [string]: TextButton } = {}
local order: { string } = {}

local function slot(id: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = id; button.Text = ""; button.AutoButtonColor = false
	button.BackgroundColor3 = T.Tile; button.Size = UDim2.fromOffset(H.HotbarCell, H.HotbarCell)
	button.Parent = bar
	Ui.Corner(button, 14); Ui.Stroke(button, 2, T.TileStroke)
	local view = Ui.ToolPreview(button, id)
	view.Position = UDim2.fromOffset(6, 6); view.Size = UDim2.new(1, -12, 1, -12)
	local key = Ui.Heading(button, "", 14)
	key.Name = "Key"; key.Position = UDim2.fromOffset(8, 4); key.Size = UDim2.fromOffset(20, 18)
	button.Activated:Connect(function() equip(id) end)
	return button
end

-- The + slot: always last, opens the Backpack.
local more = Instance.new("TextButton")
more.Name = "Backpack"; more.Text = "+"; more.FontFace = Ui.Font; more.TextSize = 44
more.TextColor3 = T.Text; more.BackgroundColor3 = T.Surface; more.LayoutOrder = 99
more.Size = UDim2.fromOffset(H.HotbarCell, H.HotbarCell); more.Parent = bar
Ui.Corner(more, 14); Ui.Stroke(more, 2, T.SurfaceStroke)
more.Activated:Connect(Backpack.Toggle)

local function refresh()
	local profile = State.Get()
	gui.Enabled = profile ~= nil and not Ui.MenuOpen
	if not profile then return end
	local ids = shown(profile)
	for id, button in slots do
		if not table.find(ids, id) then button:Destroy(); slots[id] = nil end
	end
	for index, id in ids do
		local button = slots[id] or slot(id)
		slots[id] = button
		button.LayoutOrder = index
		local equipped = id == profile.EquippedToolId
		button.BackgroundColor3 = if equipped then T.TileActive else T.Tile
		local stroke = button:FindFirstChildOfClass("UIStroke") :: UIStroke
		stroke.Color = if equipped then T.TileActiveStroke else T.TileStroke
		stroke.Thickness = if equipped then 3 else 2
		(button:FindFirstChild("Key") :: TextLabel).Text = tostring(index)
	end
	order = ids
	local def = Tools.ById[profile.EquippedToolId]
	name.Text = def and def.DisplayName or ""
	local scale = Ui.HudScale(gui.AbsoluteSize)
	name.Position = UDim2.new(0.5, 0, 1, -H.Edge - (H.HotbarCell + 8) * scale)
	name.Visible = #ids > 1
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or Ui.MenuOpen then return end
	local index = table.find({ Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six }, input.KeyCode)
	if index and order[index] then equip(order[index]) end
	if input.KeyCode == Enum.KeyCode.B then Backpack.Toggle() end
end)
State.Changed:Connect(refresh)
Ui.MenuChanged:Connect(refresh)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
refresh()
