--!strict
-- Quests page (board 4). One card per neighbor in three states:
-- new contact (Show route), known contact (Accept job, rewards) and the
-- running job (progress, time left). A red "!" marks a job you can take.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.Quests)
local Contracts = require(Shared.Config.Contracts)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Format)
local Client = require(script.Parent:WaitForChild("QuestClient"))
local Ui = require(script.Parent:WaitForChild("UiKit"))
local Land = require(script.Parent:WaitForChild("LandState"))
local T, Images = Ui.Theme, Ui.Images
local Journal = {}
local CARD_HEIGHT = 268
local TWO_COLUMNS = 520

local function line(parent: Instance, value: string, y: number, size: number?, color: Color3?): TextLabel
	local label = Ui.Heading(parent, value, size or 16, color)
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Position = UDim2.fromOffset(20, y); label.Size = UDim2.new(1, -40, 0, 44)
	return label
end

local function reward(parent: Instance, image: string, value: string, color: Color3, x: number)
	local icon = Ui.Icon(parent, image, 40)
	icon.Position = UDim2.fromOffset(x, 150)
	local label = Ui.Heading(parent, value, 23, color)
	label.Position = UDim2.fromOffset(x + 48, 150); label.Size = UDim2.fromOffset(110, 40)
end

local function timeLeft(seconds: number): string
	return if seconds > 0 then string.format("%d:%02d left", seconds // 60, seconds % 60) else "Late · reduced reward"
end

function Journal.Render(parent: Instance, profile, send, leave)
	local grid = Instance.new("Frame")
	grid.Name = "Contacts"; grid.BackgroundTransparency = 1
	grid.LayoutOrder = 1; grid.Size = UDim2.new(1, -4, 0, CARD_HEIGHT)
	grid.Parent = parent
	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.CellPadding = UDim2.fromOffset(16, 16)
	layout.Parent = grid
	local active = workspace:GetAttribute("ContractId") or ""
	local count = 0
	for index, contact in Config.List do
		if not Client.Eligible(contact.Id) then continue end
		count += 1
		local def = Contracts.Bands[index]
		local known = profile.KnownQuestContacts[contact.Id] == true
		local running = active == contact.Id
		local zone = Zones.ById[contact.ZoneId].DisplayName
		local card = Ui.Surface(grid, T.Surface, T.QuestStroke, 16)
		card.Name = contact.Id; card.LayoutOrder = index
		local icon = Ui.Icon(card, Images.Quests, 62)
		icon.Position = UDim2.fromOffset(14, 10)
		local title = Ui.Heading(card, if running then def.DisplayName elseif known then contact.NpcName else "Meet " .. contact.NpcName, 21)
		title.Position = UDim2.fromOffset(88, 22); title.Size = UDim2.new(1, -136, 0, 36)
		Ui.FitText(title, 14, 21)
		if not running and active == "" then
			local alert = Ui.AlertBadge(card)
			alert.AnchorPoint = Vector2.new(1, 0); alert.Position = UDim2.new(1, -18, 0, 6)
		end
		local goal = "Mow " .. Format.Number(def.GrassTarget) .. " grass in " .. zone .. "."
		if running then
			line(card, goal, 84)
			local progress = workspace:GetAttribute("ContractProgress") or 0
			local target = workspace:GetAttribute("ContractTarget") or def.GrassTarget
			local bar = Ui.ProgressBar(card, UDim2.new(1, -40, 0, 18))
			bar.Frame.Position = UDim2.fromOffset(20, 120); bar.Set(progress / math.max(1, target), false)
			line(card, Format.Number(progress) .. " / " .. Format.Number(target) .. " grass", 150, 19)
			local timer = line(card, "", 182, 17)
			timer:SetAttribute("CountdownEndsAt", workspace:GetAttribute("ContractEndsAt") or 0)
			timer.Text = timeLeft(math.ceil((workspace:GetAttribute("ContractEndsAt") or 0) - workspace:GetServerTimeNow()))
		elseif known then
			line(card, def.DisplayName, 78)
			line(card, goal, 102)
			reward(card, Images.Coin, Format.Number(def.Coins), T.Coins, 20)
			reward(card, Images.Clover, Format.Number(def.Clovers), T.Clovers, 170)
			line(card, math.ceil(def.DeadlineSeconds / 60) .. " minutes · party job", 196, 15, T.TextMuted)
		else
			line(card, "Follow the trail to " .. contact.NpcName .. " in " .. zone .. ".", 84)
			line(card, "Talk to your neighbor to discover their local job.", 136, 16, T.TextMuted)
		end
		local accepting = known and not running and active == "" and Client.Near(contact.Id) and Land.IsHost()
		local action = Ui.Button(card, if accepting then "Accept" else "Talk", if accepting then "ACCEPT JOB" else "SHOW ROUTE", function()
			if accepting then send("Contract", contact.Id); Client.Clear(); leave()
			else Client.Focus(contact.Id); leave() end
		end, "Blue")
		action.AnchorPoint = Vector2.new(0, 1)
		action.Position = UDim2.new(0, 20, 1, -18); action.Size = UDim2.new(1, -40, 0, 48)
		if running then
			-- The running job keeps its green "In progress" state; the host
			-- can still drop it from the small button beside it.
			Ui.Paint(action, "Progress", if Land.IsHost() then "IN PROGRESS" else "HELP YOUR PARTY", false)
			if Land.IsHost() then
				action.Size = UDim2.new(1, -150, 0, 48)
				local abandon = Ui.Button(card, "Abandon", "ABANDON", function() send("AbandonContract") end, "Close")
				abandon.AnchorPoint = Vector2.new(1, 1)
				abandon.Position = UDim2.new(1, -20, 1, -18); abandon.Size = UDim2.fromOffset(102, 48)
			end
		end
	end
	local function arrange()
		local columns = if Ui.LocalWidth(grid) >= TWO_COLUMNS then 2 else 1
		layout.CellSize = UDim2.new(1 / columns, -16 * (columns - 1) / columns, 0, CARD_HEIGHT)
		local rows = math.max(1, math.ceil(count / columns))
		grid.Size = UDim2.new(1, -4, 0, rows * CARD_HEIGHT + (rows - 1) * 16)
	end
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(arrange)
	arrange()
	if count == 0 then
		grid:Destroy()
		local empty = Ui.Heading(parent, "Your neighbors have work for you. Return to your land to meet them.", 18)
		empty.Name = "Empty"; empty.LayoutOrder = 1
		empty.Size = UDim2.new(1, -4, 0, 80)
	end
end

function Journal.UpdateTimers(parent: Instance)
	for _, child in parent:GetDescendants() do
		local deadline = child:GetAttribute("CountdownEndsAt")
		if child:IsA("TextLabel") and type(deadline) == "number" then
			child.Text = timeLeft(math.ceil(deadline - workspace:GetServerTimeNow()))
		end
	end
end

return Journal
