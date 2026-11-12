--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.Quests)
local Contracts = require(Shared.Config.Contracts)
local Zones = require(Shared.Config.Zones)
local Interface = require(Shared.Config.Interface)
local Format = require(Shared.Format)
local Client = require(script.Parent:WaitForChild("QuestClient"))
local Ui = require(script.Parent:WaitForChild("UiKit"))
local Land = require(script.Parent:WaitForChild("LandState"))
local Journal = {}
local function at(label, x, y, width, height)
	label.Position = UDim2.fromOffset(x, y)
	label.Size = UDim2.new(1, -width, 0, height)
	return label
end
function Journal.Render(parent: Instance, profile, send, leave)
	local count = 0
	local active = workspace:GetAttribute("ContractId") or ""
	for index, contact in Config.List do
		if not Client.Eligible(contact.Id) then continue end
		count += 1
		local def = Contracts.Bands[index]
		local known = profile.KnownQuestContacts[contact.Id] == true
		local running = active == contact.Id
		local frame = Instance.new("Frame")
		frame.Name = contact.Id; frame.LayoutOrder = index
		frame.BackgroundColor3 = if running then Ui.Colors.Track else Ui.Colors.Cream
		frame.Size = UDim2.new(1, 0, 0, if running then 242 else 232)
		frame.Parent = parent
		Ui.Corner(frame, 12); Ui.Stroke(frame, 1, Ui.Colors.CreamShade)
		local icon = Ui.Icon(frame, Interface.Images.Quests, 40)
		icon.Position = UDim2.fromOffset(10, 8)
		local name = at(Ui.Text(frame, if known then contact.NpcName else "Meet " .. contact.NpcName, 20), 58, 8, 70, 26)
		name.FontFace = Ui.Font
		Ui.FitText(name, 14, 20)
		at(Ui.Text(frame, Zones.ById[contact.ZoneId].DisplayName .. (if running then " · In progress" elseif known then " · Local jobs" else " · New contact"), 13), 58, 34, 70, 22)
		at(Ui.Text(frame, if known then def.DisplayName else "A neighbor needs a hand", 18), 12, 66, 24, 26)
		at(Ui.Text(frame, if known then contact.Greeting else "Follow the trail and talk to " .. contact.NpcName .. " to discover their job.", 14), 12, 96, 24, 42)
		if running then
			local progress = workspace:GetAttribute("ContractProgress") or 0
			local target = workspace:GetAttribute("ContractTarget") or def.GrassTarget
			local bar = Ui.ProgressBar(frame, UDim2.new(1, -24, 0, 12))
			bar.Frame.Position = UDim2.fromOffset(12, 146); bar.Set(progress / math.max(1, target), false)
			local remaining = math.ceil((workspace:GetAttribute("ContractEndsAt") or 0) - workspace:GetServerTimeNow())
			local prefix = Format.Number(progress) .. "/" .. Format.Number(target) .. " grass · "
			local timer = at(Ui.Text(frame, prefix .. (if remaining > 0 then remaining .. "s left" else "Late · reduced reward"), 13), 12, 164, 24, 22)
			timer:SetAttribute("CountdownEndsAt", workspace:GetAttribute("ContractEndsAt") or 0)
			timer:SetAttribute("CountdownPrefix", prefix)
		else
			local rewards = Ui.Resource(frame, "Coins", Interface.Images.Coin, 110, 26)
			rewards.Frame.Position = UDim2.fromOffset(12, 144)
			rewards.Value.Text = if known then Format.Number(def.Coins) else "?"
			rewards.Value.TextColor3 = Ui.Colors.Ink
			Ui.PlainValue(rewards.Value)
			local clovers = Ui.Resource(frame, "Clovers", Interface.Images.Clover, 100, 26)
			clovers.Frame.Position = UDim2.fromOffset(128, 144)
			clovers.Value.Text = if known then tostring(def.Clovers) else "?"
			clovers.Value.TextColor3 = Ui.Colors.Ink
			Ui.PlainValue(clovers.Value)
		end
		local accepting = known and not running and active == "" and Client.Near(contact.Id) and Land.IsHost()
		local caption = if running then "Abandon job" elseif accepting then "Accept job · " .. Format.Number(def.GrassTarget) .. " grass" else "Talk to " .. contact.NpcName
		local action = Ui.Button(frame, if accepting then "Accept" else "Talk", caption, function()
			if running then send("AbandonContract")
			elseif accepting then send("Contract", contact.Id); Client.Clear(); leave()
			else Client.Focus(contact.Id); leave() end
		end)
		action.Position = UDim2.new(0, 12, 1, -50)
		action.Size = UDim2.new(1, -24, 0, 44)
		if running and not Land.IsHost() then
			action.Text = "Help your party mow this expansion"
			action.Active = false; action.Selectable = false; action.AutoButtonColor = false
		end
	end
	if count == 0 then
		local empty = at(Ui.Text(parent, "Your neighbors have work for you. Return to your land to meet them.", 18), 12, 12, 24, 100)
		empty.Name = "Empty"
	end
end
function Journal.UpdateTimers(parent: Instance)
	for _, child in parent:GetDescendants() do
		local deadline = child:GetAttribute("CountdownEndsAt")
		if child:IsA("TextLabel") and type(deadline) == "number" then
			local remaining = math.ceil(deadline - workspace:GetServerTimeNow())
			child.Text = (child:GetAttribute("CountdownPrefix") or "") .. (if remaining > 0 then remaining .. "s left" else "Late · reduced reward")
		end
	end
end
return Journal
