--!strict
-- Right-side quest card (board 1): green-rimmed card with a header strip,
-- the next neighbor to meet and SHOW ROUTE, or the running job's progress.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Quests)
local Contracts = require(Shared.Config.Contracts)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Format)
local Client = require(script.Parent:WaitForChild("QuestClient"))
local State = require(script.Parent:WaitForChild("ClientState"))
local Ui = require(script.Parent:WaitForChild("UiKit"))
local T, H, Images = Ui.Theme, Ui.Hud, Ui.Images

local gui = Ui.LocalGui("QuestTracker")
local holder = Instance.new("Frame")
holder.Name = "Holder"; holder.BackgroundTransparency = 1
holder.AnchorPoint = Vector2.new(1, 0)
holder.Position = UDim2.new(1, -H.Edge, 0, 0)
holder.Size = UDim2.fromOffset(H.Tracker.X + 8, H.TrackerTop + H.Tracker.Y)
holder.Parent = gui
Ui.AutoScale(gui, holder)

local card = Ui.Surface(holder, T.Surface, T.TrackerStroke, 16, 2)
card.Name = "Tracker"; card.AnchorPoint = Vector2.new(1, 0)
card.Position = UDim2.new(1, 0, 0, H.TrackerTop)
card.Size = UDim2.fromOffset(H.Tracker.X, H.Tracker.Y)
local header = Ui.Surface(card, T.TrackerHeader, nil, 13)
header.Name = "Header"
header.Position = UDim2.fromOffset(3, 3); header.Size = UDim2.new(1, -6, 0, H.TrackerHeader)
local icon = Ui.Icon(card, Images.Quests, 66)
icon.Position = UDim2.fromOffset(1, -9)
local title = Ui.Heading(header, "Local jobs", 17)
title.Position = UDim2.fromOffset(64, 0); title.Size = UDim2.new(1, -96, 1, 0)
title.TextWrapped = false
Ui.FitText(title, 11, 17)
local alert = Ui.AlertBadge(card)
alert.AnchorPoint = Vector2.new(1, 0); alert.Position = UDim2.new(1, -3, 0, -12)
local objective = Ui.Heading(card, "", 17)
objective.TextYAlignment = Enum.TextYAlignment.Top
objective.Position = UDim2.fromOffset(20, 76); objective.Size = UDim2.new(1, -40, 0, 54)
Ui.FitText(objective, 12, 17)
local bar = Ui.ProgressBar(card, UDim2.new(1, -40, 0, 16))
bar.Frame.Position = UDim2.fromOffset(20, 136)
local timer = Ui.Heading(card, "", 16)
timer.Name = "Timer"; timer.Position = UDim2.fromOffset(20, 164); timer.Size = UDim2.new(1, -40, 0, 24)
local action = Ui.Button(card, "Route", "SHOW ROUTE", function()
	local id = Client.Contact()
	if id then Client.Focus(id) end
end, "Blue")
action.AnchorPoint = Vector2.new(0, 1)
action.Position = UDim2.new(0, 17, 1, -20); action.Size = UDim2.new(1, -34, 0, H.ButtonHeight)

local function update()
	local profile = State.Get()
	card.Visible = profile ~= nil and not Ui.MenuOpen
	if not profile or Ui.MenuOpen then return end
	local id = workspace:GetAttribute("ContractId") or ""
	if id ~= "" then
		local def
		for _, item in Contracts.Bands do if item.Id == id then def = item; break end end
		if not def then card.Visible = false; return end
		title.Text = def.DisplayName
		local progress = workspace:GetAttribute("ContractProgress") or 0
		local target = workspace:GetAttribute("ContractTarget") or 1
		local seconds = math.ceil((workspace:GetAttribute("ContractEndsAt") or 0) - workspace:GetServerTimeNow())
		objective.Text = "Mow in " .. Zones.List[def.MinExpansion].DisplayName .. ": " .. Format.Number(progress) .. " / " .. Format.Number(target) .. " grass"
		bar.Frame.Visible = true; bar.Set(progress / math.max(1, target), false)
		timer.Visible = true
		timer.Text = if seconds > 0 then string.format("%d:%02d left", seconds // 60, seconds % 60) else "Late · reduced reward"
		action.Visible = false; alert.Visible = false
		card.Size = UDim2.fromOffset(H.Tracker.X, 200)
	else
		local contactId = Client.Contact()
		if not contactId then card.Visible = false; return end
		local def = Config.ById[contactId]
		local known = profile.KnownQuestContacts[contactId]
		title.Text = (if known then "Talk to " else "Meet ") .. def.NpcName
		objective.Text = if Client.Near(contactId) then "Talk to " .. def.NpcName .. " for a local job." else "Follow the trail to your neighbor."
		bar.Frame.Visible = false; timer.Visible = false
		action.Visible = true; alert.Visible = true
		Ui.Paint(action, "Blue", if Client.Tracked() == contactId then "FOLLOWING TRAIL" else "SHOW ROUTE")
		card.Size = UDim2.fromOffset(H.Tracker.X, H.Tracker.Y)
	end
end
State.Changed:Connect(update)
Ui.MenuChanged:Connect(update)
task.spawn(function() while gui.Parent do update(); task.wait(0.5) end end)
