--!strict
-- Reference-driven farm HUD extension. Real prices/rewards come from configs;
-- the reference's illustrated Robux offers are not the game's catalog.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tuning = require(Shared.Config.Progression)
local Interface = require(Shared.Config.Interface)
local Zones = require(Shared.Config.Zones)
local Seeds = require(Shared.Config.Seeds)
local Contracts = require(Shared.Config.Contracts)
local Franchise = require(Shared.Config.Franchise)
local Weather = require(Shared.Config.Weather)
local Rules = require(Shared.ProgressionRules)
local Format = require(Shared.Format)
local State = require(script.Parent:WaitForChild("ClientState"))
local Ui = require(script.Parent:WaitForChild("UiKit"))
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local profile = State.Get()
local page = "Crew"
local pending: { [string]: number } = {}
local offer = 0
local C = Ui.Colors
local gui = Instance.new("ScreenGui")
gui.Name = "Operations"
gui.ResetOnSpawn = false
gui.DisplayOrder = 8
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local function text(parent, value, size)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = Ui.FontBold
	label.TextColor3 = C.Ink
	label.TextSize = size
	label.Text = value
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end
local function button(parent, name, value, callback)
	local item = Instance.new("TextButton")
	item.Name = name
	item.BackgroundColor3 = C.Gold
	item.FontFace = Ui.Font
	item.TextColor3 = C.Ink
	item.TextSize = 16
	item.Text = value
	item.AutoButtonColor = true
	item.Selectable = true
	item.Parent = parent
	Ui.Corner(item, 10); Ui.Stroke(item, 2)
	item.Activated:Connect(callback)
	return item
end
local panel: Frame
local function openPage(name: string)
	page = name; offer = 0; panel.Visible = true
	local shop = player.PlayerGui:FindFirstChild("ShopGui")
	local shopPanel = shop and shop:FindFirstChild("Shop")
	if shopPanel and shopPanel:IsA("GuiObject") then shopPanel.Visible = false end
end
local function send(action: string, id: string?)
	local key = action .. (id or "")
	if (pending[key] or 0) > os.clock() then return end
	pending[key] = os.clock() + 0.5
	(remotes.GameAction :: RemoteEvent):FireServer(action, id or "")
end
local statusCard = Ui.Card(gui, 10)
statusCard.AnchorPoint = Vector2.new(1, 0)
statusCard.Position = UDim2.new(1, -12, 0, 8)
statusCard.Size = UDim2.fromOffset(220, 54)
local status = text(statusCard, "Loading your company...", 16)
status.AnchorPoint = Vector2.new(1, 0)
status.Position = UDim2.new(1, -8, 0, 0)
status.Size = UDim2.new(1, -16, 1, 0)
status.TextXAlignment = Enum.TextXAlignment.Right
local objectiveCard = Ui.Card(gui, 10)
objectiveCard.AnchorPoint = Vector2.new(1, 0)
objectiveCard.Position = UDim2.new(1, -12, 0, 70)
objectiveCard.Size = UDim2.fromOffset(220, 80)
local objective = text(objectiveCard, "", 15)
objective.AnchorPoint = Vector2.new(1, 0)
objective.Position = UDim2.new(1, -8, 0, 4)
objective.Size = UDim2.new(1, -16, 1, -8)
objective.TextXAlignment = Enum.TextXAlignment.Right
local navigation = Instance.new("Frame")
navigation.Name = "Navigation"
navigation.BackgroundTransparency = 1
navigation.Position = UDim2.fromOffset(12, 12)
navigation.Size = UDim2.fromOffset(Interface.NavigationWidth, 168)
navigation.Parent = gui
local stack = Instance.new("UIGridLayout")
stack.CellSize = UDim2.fromOffset(84, 76)
stack.CellPadding = UDim2.fromOffset(8, 8)
stack.SortOrder = Enum.SortOrder.LayoutOrder
stack.Parent = navigation
panel = Ui.Card(gui)
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.94, 0.82)
panel.Visible = false
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Interface.PanelMaxSize; limit.Parent = panel
local header = Instance.new("Frame")
header.BackgroundColor3 = C.Gold
header.Position = UDim2.fromOffset(12, 12)
header.Size = UDim2.new(1, -24, 0, 48)
header.Parent = panel
Ui.Corner(header, 12); Ui.Stroke(header, 2)
local title = text(header, "CREW", 25)
title.Position = UDim2.fromOffset(12, 0); title.Size = UDim2.new(1, -70, 1, 0)
local close = button(header, "Close", "X", function()
	panel.Visible = false; offer = 0; GuiService.SelectedObject = nil
end)
close.BackgroundColor3 = C.Coral
close.AnchorPoint = Vector2.new(1, 0.5)
close.Position = UDim2.new(1, -2, 0.5, 0)
close.Size = UDim2.fromOffset(44, 44)
local tabBar = Instance.new("ScrollingFrame")
tabBar.BorderSizePixel = 0
tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
tabBar.CanvasSize = UDim2.new()
tabBar.ScrollBarThickness = 3
tabBar.ScrollingDirection = Enum.ScrollingDirection.X
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 6)
tabLayout.Parent = tabBar
tabBar.BackgroundTransparency = 1
tabBar.Position = UDim2.fromOffset(12, 70)
tabBar.Size = UDim2.new(1, -24, 0, 44)
tabBar.Parent = panel
local list = Instance.new("ScrollingFrame")
list.Name = "Rows"
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Position = UDim2.fromOffset(12, 124)
list.Size = UDim2.new(1, -24, 1, -136)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.ScrollBarThickness = 5
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = list
local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 3); padding.PaddingRight = UDim.new(0, 8)
padding.PaddingTop = UDim.new(0, 3); padding.PaddingBottom = UDim.new(0, 3); padding.Parent = list
local sequence = 0
local function row(name: string, detail: string, actionText: string?, callback, enabled: boolean?)
	sequence += 1
	local frame = Instance.new("Frame")
	frame.Name = "Row" .. sequence
	frame.LayoutOrder = sequence
	frame.Size = UDim2.new(1, 0, 0, if actionText then 126 else 76)
	frame.BackgroundColor3 = C.Track
	frame.Parent = list
	Ui.Corner(frame, 10)
	local label = text(frame, name, 18)
	label.Position = UDim2.fromOffset(10, 6); label.Size = UDim2.new(1, -20, 0, 28)
	local description = text(frame, detail, 14)
	description.Position = UDim2.fromOffset(10, 36); description.Size = UDim2.new(1, -20, 0, 34)
	if actionText then
		local action = button(frame, "Action", actionText, callback)
		action.Position = UDim2.new(0, 10, 1, -48); action.Size = UDim2.new(1, -20, 0, 40)
		if enabled == false then action.BackgroundColor3 = C.CreamShade; action.Active = false; action.Selectable = false; action.AutoButtonColor = false end
	end
end
local render
local tabs = { "Crew", "Market", "Jobs", "Garden", "Rewards", "Franchise" }
for index, name in tabs do
	local item = button(tabBar, name, name, function() page = name; offer = 0; render() end)
	item.LayoutOrder = index
	item.Size = UDim2.new(0, 90, 1, -4)
	item.TextSize = 12
end
render = function()
	if not panel.Visible then return end
	for _, child in list:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
	sequence = 0; title.Text = string.upper(page)
	if not profile then row("Loading", "Your saved company is loading. Please wait."); return end
	if page == "Crew" then
		row("Your Crew", #profile.EquippedCrew .. " / " .. Rules.CrewSlots(profile) .. " equipped. Merge 3 matching copies to evolve.")
		local ids = {}
		for uid in profile.Crew do table.insert(ids, uid) end
		table.sort(ids, function(a, b) return tonumber(a) < tonumber(b) end)
		if #ids == 0 then row("A little help on the lawn", "Earn Clovers from mowing, rewards and jobs, then visit Market.") end
		for _, uid in ids do
			local entry = profile.Crew[uid]
			local def = Rules.CrewDef(entry.Id)
			if not def then continue end
			local equipped = table.find(profile.EquippedCrew, uid) ~= nil
			row(def.DisplayName .. " • " .. def.Rarity, "Evolution " .. entry.Evolution .. " / " .. entry.Mode,
				if equipped then "Unequip" else "Equip", function() send("EquipCrew", uid) end)
			if equipped then row("Work mode", "Stand in an unlocked lawn to station this Crew here.", if entry.Mode == "Station" then "Follow me" else "Station here", function() send("CrewMode", uid) end) end
			row("Evolve " .. def.DisplayName, "Consumes 3 matching copies. Keeps one stronger Crew.", "Merge copies", function() send("MergeCrew", uid) end, entry.Evolution < Tuning.MaxEvolution)
		end
	elseif page == "Market" then
		local epoch, shelf = Rules.Shelf(os.time())
		row("Crew Market", "Next restock in " .. (Tuning.RestockSeconds - os.time() % Tuning.RestockSeconds) .. "s. Stock is personal; earn Clovers in play.")
		for _, item in shelf do
			local def = Rules.CrewDef(item.Id)
			if not profile.UnlockedZoneIds[def.Expansion] then continue end
			local bought = if profile.MarketEpoch == epoch then profile.MarketBought[item.Id] or 0 else 0
			row(def.DisplayName .. " • " .. def.Rarity, (item.Stock - bought) .. " left · " .. item.Price .. " Clovers", "Hire Crew", function() send("BuyCrew", item.Id) end, bought < item.Stock and profile.Clovers >= item.Price)
		end
	elseif page == "Jobs" then
		row("Party jobs", "Mow the named expansion. Everyone present at acceptance and qualified receives the full reward.")
		for _, def in Contracts.Bands do
			row(def.DisplayName, def.GrassTarget .. " grass · " .. def.DeadlineSeconds .. " seconds · " .. Format.Number(def.Coins) .. " Coins", "Accept job", function() send("Contract", def.Id) end, profile.UnlockedZoneIds[Zones.List[def.MinExpansion].Id] == true)
		end
		row("Current job", "Late completion pays a reduced reward. Abandoning has no fee.", "Abandon job", function() send("AbandonContract") end)
	elseif page == "Garden" then
		row("Planting beds", "Two beds near each lawn's edge. Walk to the beds, plant, then cut mature grass. Growth continues offline.")
		for _, plot in profile.Plots do
			local seed = Seeds.ById[plot.SeedId]
			row(seed.DisplayName, if os.time() >= plot.ReadyAt then "Ready! Cut at the bed to harvest Golden grass." else math.ceil((plot.ReadyAt - os.time()) / 60) .. " minutes until harvest.")
		end
		for _, seed in Seeds.List do
			if profile.UnlockedZoneIds[seed.Expansion] then
				row(seed.DisplayName, Zones.ById[seed.Expansion].DisplayName .. " · " .. math.ceil(seed.GrowSeconds / 60) .. " min · " .. Tuning.SeedPricePerZone * Zones.IndexById[seed.Expansion] .. " Coins", "Plant seed", function() send("Plant", seed.Id) end)
			end
		end
	elseif page == "Rewards" then
		row("Daily reward", "Return each day for Coins and Clovers. Current streak: " .. profile.DailyStreak .. " / 7.", "Collect daily reward", function() send("Daily") end, os.time() - profile.DailyClaimAt >= Tuning.DailySeconds)
		row("While you were away", Format.Number(profile.OfflineGrass) .. " grass waiting · offline cap " .. Rules.OfflineHours(profile) .. "h. Collect into storage, then sell physically.", "Collect offline grass", function() send("CollectOffline") end, profile.OfflineGrass > 0)
		local step = Tuning.Tutorial[profile.TutorialStep]
		row("Your next objective", if step then step.Text else "First loop complete! Grow your company, unlock Mega Fields, then Franchise.")
	else
		row("Your company", Format.Number(profile.RunCoins) .. " Coins earned this run · " .. profile.FranchisePoints .. " points available · " .. profile.Franchises .. " franchises.")
		if offer > 0 then
			row("Confirm Franchise for " .. offer .. " points?", "Resets Coins, tools, storage, expansions, buffs, plots and Company Level. Keeps Crew, Clovers and permanent upgrades.", "Confirm reset and Franchise", function() send("FranchiseConfirm"); offer = 0 end)
		else
			row("Start a stronger company", "Unlock Mega Fields and earn at least " .. Format.Number(Franchise.FirstPointAtLifetimeCoins) .. " Coins this run. Review the reset before confirming.", "Review Franchise", function() send("FranchisePreview") end)
		end
		for _, node in Franchise.Nodes do
			row(node.DisplayName .. " " .. (profile.FranchiseRanks[node.Id] or 0) .. "/" .. node.MaxRank, node.Effect .. " · " .. node.CostPerRank .. " points", "Buy permanent upgrade", function() send("BuyNode", node.Id) end, profile.FranchisePoints >= node.CostPerRank and (profile.FranchiseRanks[node.Id] or 0) < node.MaxRank)
		end
	end
end
for index, name in { "Crew", "Shop", "Jobs", "Rewards" } do
	local item = button(navigation, name, if name == "Jobs" then "Quests" else name, function()
		if name == "Shop" then
			panel.Visible = false
			local event = script.Parent:FindFirstChild("OpenShop")
			if event and event:IsA("BindableEvent") then event:Fire() end
		else openPage(name); render(); GuiService.SelectedObject = close end
	end)
	item.LayoutOrder = index
	item.TextYAlignment = Enum.TextYAlignment.Bottom
	item.TextColor3 = C.Cream
	item.TextStrokeColor3 = C.Ink
	item.TextStrokeTransparency = 0
	item.BackgroundTransparency = 1
	local stroke = item:FindFirstChildOfClass("UIStroke")
	if stroke then stroke:Destroy() end
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Image = Interface.Images[if name == "Jobs" then "Quests" else name]
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0)
	icon.Size = UDim2.fromOffset(56, 56)
	icon.Parent = item
end
local dirty = false
State.Changed:Connect(function(data) profile = data; table.clear(pending); dirty = true end);
(remotes.FranchiseOffer :: RemoteEvent).OnClientEvent:Connect(function(points) offer = points; page = "Franchise"; panel.Visible = true; render() end)
task.spawn(function()
	local lastEpoch = -1
	while gui.Parent do
		local epoch = math.floor(os.time() / Tuning.RestockSeconds)
		if epoch ~= lastEpoch and page == "Market" then dirty = true end
		lastEpoch = epoch
		if dirty then dirty = false; render() end
		local weather = Weather.ById[workspace:GetAttribute("WeatherId") or "clear"]
		local seconds = math.max(0, math.ceil((workspace:GetAttribute("WeatherEndsAt") or 0) - workspace:GetServerTimeNow()))
		status.Text = (weather and weather.DisplayName or "Clear Skies") .. " " .. math.floor(seconds / 60) .. ":" .. string.format("%02d", seconds % 60) .. "\n" .. (if profile then Format.Number(profile.Clovers) .. " Clovers · Fuel " .. math.floor(profile.Fuel) .. "%" else "Loading...")
		local contract = workspace:GetAttribute("ContractId") or ""
		if contract ~= "" then
			local remaining = math.ceil((workspace:GetAttribute("ContractEndsAt") or 0) - workspace:GetServerTimeNow())
			objective.Text = "Job · " .. tostring(workspace:GetAttribute("ContractProgress")) .. "/" .. tostring(workspace:GetAttribute("ContractTarget")) .. "\n" .. (if remaining > 0 then remaining .. "s left" else "Late delivery · reduced reward")
		else
			local step = profile and Tuning.Tutorial[profile.TutorialStep]
			objective.Text = if step then step.Text else "Unlock every expansion, then Franchise."
		end
		task.wait(1)
	end
end)
