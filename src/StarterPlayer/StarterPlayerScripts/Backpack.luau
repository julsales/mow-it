--!strict
-- Backpack window, opened from the hotbar's + slot: every collectible the
-- player owns (tools, Crew, storage, carried grass) as cards, with filter
-- tabs. Clicking a tool or storage equips it; clicking Crew equips or
-- unequips it. The server validates everything (BuyTool / BuyBackpack
-- re-equip owned items, GameAction EquipCrew).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tools = require(Shared.Config.Tools)
local Backpacks = require(Shared.Config.Backpacks)
local Interface = require(Shared.Config.Interface)
local Weather = require(Shared.Config.Weather)
local Rules = require(Shared.ProgressionRules)
local Format = require(Shared.Format)
local State = require(script.Parent:WaitForChild("ClientState"))
local Ui = require(script.Parent:WaitForChild("UiKit"))
local T, B, Images = Ui.Theme, Interface.Backpack, Ui.Images
local remotes = ReplicatedStorage:WaitForChild("Remotes")

type Item = {
	Kind: string, Key: string, Name: string, Detail: string, Equipped: boolean,
	Tool: string?, Image: string?, Tint: Color3?, Accent: Color3?, Action: (() -> ())?,
}

local Backpack = {}
local gui = Ui.LocalGui("BackpackGui", 8)
local window = Ui.Window(gui, "Backpack", "BACKPACK", Images.Grass)
local filter = "All"
local tabs: { [string]: TextButton } = {}

local function fire(name: string, ...)
	(remotes:WaitForChild(name) :: RemoteEvent):FireServer(...)
end

-- Everything collectible, in a stable order per kind.
local function collect(profile): { Item }
	local items: { Item } = {}
	for index = #Tools.List, 1, -1 do
		local def = Tools.List[index]
		if profile.OwnedToolIds[def.Id] then
			table.insert(items, { Kind = "Tools", Key = def.Id, Name = def.DisplayName, Detail = "Power " .. Format.Number(def.Power),
				Equipped = profile.EquippedToolId == def.Id, Tool = def.Id, Action = function() fire("BuyTool", def.Id) end })
		end
	end
	local uids = {}
	for uid in profile.Crew do table.insert(uids, uid) end
	table.sort(uids, function(a, b) return tonumber(a) < tonumber(b) end)
	for _, uid in uids do
		local entry = profile.Crew[uid]
		local def = Rules.CrewDef(entry.Id)
		if def then
			table.insert(items, { Kind = "Crew", Key = "crew" .. uid, Name = def.DisplayName, Detail = def.Rarity .. " · Evo " .. entry.Evolution,
				Equipped = table.find(profile.EquippedCrew, uid) ~= nil, Image = Images.Crew, Accent = B.Rarity[def.Rarity],
				Action = function() fire("GameAction", "EquipCrew", uid) end })
		end
	end
	for index = #Backpacks.List, 1, -1 do
		local def = Backpacks.List[index]
		if profile.OwnedBackpackIds[def.Id] then
			table.insert(items, { Kind = "Storage", Key = def.Id, Name = def.DisplayName, Detail = "Holds " .. Format.Number(def.Capacity),
				Equipped = profile.EquippedBackpackId == def.Id, Image = Images.Passes, Action = function() fire("BuyBackpack", def.Id) end })
		end
	end
	for _, weather in Weather.List do
		local count = profile.GrassByVariant[weather.VariantId] or 0
		if count > 0 then
			table.insert(items, { Kind = "Grass", Key = weather.VariantId, Name = B.GrassNames[weather.VariantId] or weather.VariantId,
				Detail = Format.Number(count) .. " carried", Equipped = false, Image = Images.Grass, Tint = B.GrassTints[weather.VariantId] })
		end
	end
	return items
end

local function card(item: Item, order: number)
	local frame = Instance.new("TextButton")
	frame.Name = item.Key; frame.Text = ""; frame.LayoutOrder = order
	frame.AutoButtonColor = item.Action ~= nil; frame.Selectable = item.Action ~= nil
	frame.BackgroundColor3 = if item.Equipped then T.TileActive else T.Tile
	frame.Parent = window.Body:FindFirstChild("Grid")
	Ui.Corner(frame, 14)
	Ui.Stroke(frame, if item.Equipped then 3 else 1.5, if item.Equipped then T.TileActiveStroke else item.Accent or T.TileStroke)
	local preview: GuiObject
	if item.Tool then
		preview = Ui.ToolPreview(frame, item.Tool)
	else
		local icon = Ui.Icon(frame, item.Image or "", B.Preview)
		icon.ImageColor3 = item.Tint or Color3.new(1, 1, 1)
		preview = icon
	end
	preview.AnchorPoint = Vector2.new(0.5, 0)
	preview.Position = UDim2.new(0.5, 0, 0, 10); preview.Size = UDim2.fromOffset(B.Preview, B.Preview)
	local name = Ui.Heading(frame, item.Name, 15)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.Position = UDim2.fromOffset(6, B.Preview + 14); name.Size = UDim2.new(1, -12, 0, 36)
	Ui.FitText(name, 10, 15)
	local detail = Ui.Text(frame, if item.Equipped then "EQUIPPED" else item.Detail, 13, if item.Equipped then T.Clovers else item.Accent or T.TextMuted)
	detail.TextXAlignment = Enum.TextXAlignment.Center
	detail.Position = UDim2.new(0, 6, 1, -26); detail.Size = UDim2.new(1, -12, 0, 18)
	Ui.FitText(detail, 9, 13)
	if item.Action then frame.Activated:Connect(item.Action) end
end

local function render()
	if not window.Panel.Visible then return end
	local profile = State.Get()
	for _, child in window.Body:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
	for name, tab in tabs do Ui.Paint(tab, if name == filter then "Blue" else "Muted") end
	if not profile then return end
	local grid = Instance.new("Frame")
	grid.Name = "Grid"; grid.BackgroundTransparency = 1
	grid.AutomaticSize = Enum.AutomaticSize.Y; grid.Size = UDim2.new(1, -4, 0, 0)
	grid.LayoutOrder = 1; grid.Parent = window.Body
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(B.Card.X, B.Card.Y)
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local count = 0
	for _, item in collect(profile) do
		if filter == "All" or item.Kind == filter then
			count += 1
			card(item, count)
		end
	end
	if count == 0 then
		grid:Destroy()
		local empty = Ui.Heading(window.Body, "Nothing here yet. Mow, buy and hire to fill your backpack.", 17, T.TextMuted)
		empty.Name = "Empty"; empty.LayoutOrder = 1; empty.Size = UDim2.new(1, -4, 0, 60)
	end
end

for index, name in B.Filters do
	local tab = Ui.Tab(window.Tabs, name, index, function() filter = name; render() end)
	tab.Size = UDim2.fromOffset(124, 40)
	tabs[name] = tab
end
window.SetTabs(true)
window.SetSubtitle("Everything you've collected. Click to equip.")

function Backpack.Toggle()
	if window.Panel.Visible then window.Panel.Visible = false; return end
	Ui.OpenPanel(window.Panel)
	render()
end

State.Changed:Connect(render)
return Backpack
