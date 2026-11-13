--!strict
-- Menu tiles (Crew / Shop / Quests / Rewards) and the one window they open.
-- Layout from board 1 (tiles) and boards 1-4 (window pages). Real prices and
-- rewards come from configs; page content is rendered by PassShop,
-- RewardsPanel and QuestJournal, the rest by UiKit.Row.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tuning = require(Shared.Config.Progression)
local Interface = require(Shared.Config.Interface)
local Zones = require(Shared.Config.Zones)
local Seeds = require(Shared.Config.Seeds)
local Franchise = require(Shared.Config.Franchise)
local Journal = require(script.Parent:WaitForChild("QuestJournal"))
local RewardsPanel = require(script.Parent:WaitForChild("RewardsPanel"))
local PassShop = require(script.Parent:WaitForChild("PassShop"))
local QuestClient = require(script.Parent:WaitForChild("QuestClient"))
local Rules = require(Shared.ProgressionRules)
local Format = require(Shared.Format)
local State = require(script.Parent:WaitForChild("ClientState"))
local Ui = require(script.Parent:WaitForChild("UiKit"))
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local H, Images = Ui.Hud, Ui.Images
local profile = State.Get()
local page = "Crew"
local pending: { [string]: number } = {}
local offer = 0

-- Title, icon, subtitle and tab group of every page.
local PAGES = {
	Crew = { Title = "CREW", Icon = "Crew", Tabs = { "Crew", "Market" } },
	Market = { Title = "CREW", Icon = "Crew", Tabs = { "Crew", "Market" } },
	Shop = { Title = "PASSES", Icon = "Passes", Subtitle = "Make room for a bigger harvest." },
	Jobs = { Title = "QUESTS", Icon = "Quests", Subtitle = "Discover your neighbors, talk, then mow their lawns." },
	Rewards = { Title = "DAILY REWARDS", Icon = "Rewards", Tabs = { "Rewards", "Garden", "Franchise" } },
	Garden = { Title = "GARDEN", Icon = "Grass", Tabs = { "Rewards", "Garden", "Franchise" } },
	Franchise = { Title = "FRANCHISE", Icon = "Coins", Tabs = { "Rewards", "Garden", "Franchise" } },
}

local gui = Ui.LocalGui("Operations", 8)
local window = Ui.Window(gui, "Panel", "CREW", Images.Crew)
local panel, list = window.Panel, window.Body

local function send(action: string, id: string?)
	local key = action .. (id or "")
	if (pending[key] or 0) > os.clock() then return end
	pending[key] = os.clock() + 0.5
	(remotes.GameAction :: RemoteEvent):FireServer(action, id or "")
end
local function leave() panel.Visible = false; GuiService.SelectedObject = nil end

local render: () -> ()
local renderedPage = ""
local tabs: { [string]: TextButton } = {}
for index, name in { "Crew", "Market", "Rewards", "Garden", "Franchise" } do
	tabs[name] = Ui.Tab(window.Tabs, name, index, function() page = name; offer = 0; render() end)
end

local sequence = 0
local function row(title: string, detail: string, action: string?, callback: (() -> ())?, enabled: boolean?)
	sequence += 1
	local frame = Ui.Row(list, sequence, title, detail, action, callback)
	if action and enabled == false then Ui.Paint(frame:FindFirstChild("Action") :: TextButton, "Disabled") end
end

render = function()
	if not panel.Visible then return end
	for _, child in list:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
	sequence = 0
	local def = PAGES[page]
	window.Title.Text = def.Title
	window.Icon.Image = Images[def.Icon]
	window.SetSubtitle(def.Subtitle or "")
	local group = def.Tabs or {}
	for name, tab in tabs do
		tab.Visible = table.find(group, name) ~= nil
		Ui.Paint(tab, if name == page then "Blue" else "Muted")
	end
	window.SetTabs(#group > 0)
	if renderedPage ~= page then list.CanvasPosition = Vector2.zero; renderedPage = page end
	if not profile then row("Loading", "Your saved company is loading. Please wait."); return end
	if page == "Shop" then
		PassShop.Render(list, profile)
	elseif page == "Crew" then
		row("Your Crew", #profile.EquippedCrew .. " / " .. Rules.CrewSlots(profile) .. " equipped. Merge 3 matching copies to evolve.")
		local ids = {}
		for uid in profile.Crew do table.insert(ids, uid) end
		table.sort(ids, function(a, b) return tonumber(a) < tonumber(b) end)
		if #ids == 0 then row("A little help on the lawn", "Earn Clovers from mowing, rewards and jobs, then visit Market.") end
		for _, uid in ids do
			local entry = profile.Crew[uid]
			local crew = Rules.CrewDef(entry.Id)
			if not crew then continue end
			local equipped = table.find(profile.EquippedCrew, uid) ~= nil
			row(crew.DisplayName .. " • " .. crew.Rarity, "Evolution " .. entry.Evolution .. " / " .. entry.Mode,
				if equipped then "Unequip" else "Equip", function() send("EquipCrew", uid) end)
			if equipped then row("Work mode", "Stand in an unlocked lawn to station this Crew here.", if entry.Mode == "Station" then "Follow me" else "Station here", function() send("CrewMode", uid) end) end
			row("Evolve " .. crew.DisplayName, "Consumes 3 matching copies. Keeps one stronger Crew.", "Merge copies", function() send("MergeCrew", uid) end, entry.Evolution < Tuning.MaxEvolution)
		end
	elseif page == "Market" then
		local epoch, shelf = Rules.Shelf(os.time())
		row("Crew Market", "Next restock in " .. (Tuning.RestockSeconds - os.time() % Tuning.RestockSeconds) .. "s. Stock is personal; earn Clovers in play.")
		for _, item in shelf do
			local crew = Rules.CrewDef(item.Id)
			if not profile.UnlockedZoneIds[crew.Expansion] then continue end
			local bought = if profile.MarketEpoch == epoch then profile.MarketBought[item.Id] or 0 else 0
			row(crew.DisplayName .. " • " .. crew.Rarity, (item.Stock - bought) .. " left · " .. item.Price .. " Clovers", "Hire Crew", function() send("BuyCrew", item.Id) end, bought < item.Stock and profile.Clovers >= item.Price)
		end
	elseif page == "Jobs" then
		Journal.Render(list, profile, send, leave)
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
		RewardsPanel.Render(list, profile, send)
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

local function openPage(name: string)
	page = name; offer = 0; Ui.OpenPanel(panel)
	local shop = player.PlayerGui:FindFirstChild("ShopGui")
	local shopPanel = shop and shop:FindFirstChild("Shop")
	if shopPanel and shopPanel:IsA("GuiObject") then shopPanel.Visible = false end
	render()
end

-- Menu tiles: a 2x2 grid on the left rail (board 1 at 20,222).
local navigation = Instance.new("Frame")
navigation.Name = "Navigation"; navigation.BackgroundTransparency = 1
navigation.Size = UDim2.fromOffset(H.Edge + 4 + 2 * H.Tile + H.TileGap, H.RailTop + 2 * H.Tile + H.TileGap)
navigation.Parent = gui
Ui.AutoScale(gui, navigation)
local questAlert: ImageLabel
for index, def in Interface.Navigation do
	local tile = Ui.NavTile(navigation, def, function()
		openPage(def.Page)
		GuiService.SelectedObject = if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then window.Close else nil
	end)
	tile.LayoutOrder = index
	tile.Position = UDim2.fromOffset(H.Edge + 4 + ((index - 1) % 2) * (H.Tile + H.TileGap), H.RailTop + (index - 1) // 2 * (H.Tile + H.TileGap))
	if def.Page == "Jobs" then
		questAlert = Ui.AlertBadge(tile)
		questAlert.AnchorPoint = Vector2.new(1, 0)
		questAlert.Position = UDim2.new(1, -2, 0, -10)
	end
end

local dirty = false
State.Changed:Connect(function(data) profile = data; table.clear(pending); dirty = true end);
(remotes.FranchiseOffer :: RemoteEvent).OnClientEvent:Connect(function(points) offer = points; openPage("Franchise") end)
task.spawn(function()
	local lastEpoch = -1
	while gui.Parent do
		local epoch = math.floor(os.time() / Tuning.RestockSeconds)
		if epoch ~= lastEpoch and page == "Market" then dirty = true end
		lastEpoch = epoch
		if dirty then dirty = false; render() end
		if panel.Visible and page == "Jobs" then Journal.UpdateTimers(list) end
		questAlert.Visible = profile ~= nil and QuestClient.Available()
		task.wait(1)
	end
end)
Ui.MenuChanged:Connect(function(open) navigation.Visible = not open end)
QuestClient.Offered:Connect(function(id)
	openPage("Jobs"); GuiService.SelectedObject = nil
	task.defer(function()
		local contact = list:FindFirstChild(id)
		if panel.Visible and page == "Jobs" and contact and contact:IsA("GuiObject") then
			list.CanvasPosition = Vector2.new(0, math.max(0, contact.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y))
		end
	end)
end)
for _, attribute in { "ContractId", "ContractProgress", "ContractTarget" } do
	workspace:GetAttributeChangedSignal(attribute):Connect(function() dirty = true end)
end
