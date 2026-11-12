--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Quests)
local Contracts = require(Shared.Config.Contracts)
local Zones = require(Shared.Config.Zones)
local Interface = require(Shared.Config.Interface)
local Format = require(Shared.Format)
local Client = require(script.Parent:WaitForChild("QuestClient"))
local State = require(script.Parent:WaitForChild("ClientState"))
local Ui = require(script.Parent:WaitForChild("UiKit"))
local gui = Instance.new("ScreenGui")
gui.Name = "QuestTracker"; gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local card = Ui.Card(gui, 12)
card.Name = "Tracker"; card.AnchorPoint = Vector2.new(1, 0)
card.Position = UDim2.new(1, -Interface.Hud.Edge, 0, Interface.Hud.TrackerTop)
card.Size = UDim2.fromOffset(Interface.Hud.TrackerWidth, 154)
local icon = Ui.Icon(card, Interface.Images.Quests, 32)
icon.Position = UDim2.fromOffset(8, 7)
local title = Ui.Text(card, "Local jobs", 17)
title.FontFace = Ui.Font
title.Position = UDim2.fromOffset(44, 8); title.Size = UDim2.new(1, -52, 0, 28)
Ui.FitText(title, 13, 17)
local objective = Ui.Text(card, "", 14)
objective.Position = UDim2.fromOffset(12, 42); objective.Size = UDim2.new(1, -24, 0, 38)
local bar = Ui.ProgressBar(card, UDim2.new(1, -24, 0, 10))
bar.Frame.Position = UDim2.fromOffset(12, 86)
local action = Ui.Button(card, "Route", "Show route", function()
	local id = Client.Contact()
	if id then Client.Focus(id) end
end)
action.Position = UDim2.new(0, 10, 1, -50); action.Size = UDim2.new(1, -20, 0, 40)
local timer = Ui.Text(card, "", 13)
timer.Name = "Timer"; timer.Position = UDim2.fromOffset(12, 100); timer.Size = UDim2.new(1, -24, 0, 20)
local function update()
	local profile = State.Get()
	card.Visible = profile ~= nil and not Ui.MenuOpen
	if not profile or Ui.MenuOpen then return end
	local id = workspace:GetAttribute("ContractId") or ""
	local compact = gui.AbsoluteSize.Y < Interface.Hud.CompactHeight
	card.Size = UDim2.fromOffset(if compact then 230 else Interface.Hud.TrackerWidth, if compact then 142 else 154)
	if id ~= "" then
		local def
		for _, item in Contracts.Bands do if item.Id == id then def = item; break end end
		if not def then card.Visible = false; return end
		title.Text = def.DisplayName
		local progress = workspace:GetAttribute("ContractProgress") or 0
		local target = workspace:GetAttribute("ContractTarget") or 1
		local seconds = math.ceil((workspace:GetAttribute("ContractEndsAt") or 0) - workspace:GetServerTimeNow())
		objective.Text = "Mow in " .. Zones.List[def.MinExpansion].DisplayName .. "\n" .. Format.Number(progress) .. "/" .. Format.Number(target) .. " grass"
		bar.Frame.Visible = true; bar.Set(progress / math.max(1, target), false)
		action.Visible = false
		card.Size = UDim2.fromOffset(if compact then 230 else Interface.Hud.TrackerWidth, 126)
		timer.Text = if seconds > 0 then string.format("%d:%02d left", seconds // 60, seconds % 60) else "Late · reduced reward"
		timer.Visible = true
	else
		local contactId = Client.Contact()
		if not contactId then card.Visible = false; return end
		local def = Config.ById[contactId]
		title.Text = (if profile.KnownQuestContacts[contactId] then "Talk to " else "Meet ") .. def.NpcName
		objective.Text = if Client.Near(contactId) then "Talk to " .. def.NpcName .. " for a local job." else "A neighbor needs help in " .. Zones.ById[def.ZoneId].DisplayName .. "."
		bar.Frame.Visible = false; action.Visible = true
		action.Text = if Client.Tracked() == contactId then "Following trail · " .. def.NpcName else "Show route to NPC"
		timer.Visible = false
	end
end
State.Changed:Connect(update)
Ui.MenuChanged:Connect(update)
task.spawn(function() while gui.Parent do update(); task.wait(0.5) end end)
