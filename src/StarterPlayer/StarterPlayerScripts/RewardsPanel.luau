--!strict
-- Daily Rewards page (board 3): gift header, a week of day tiles (today in
-- green), today's Coins/Clovers with the collect button, then the crew's
-- offline harvest card.
local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Config.Progression)
local Interface = require(Shared.Config.Interface)
local Format = require(Shared.Format)
local Rules = require(Shared.ProgressionRules)
local Ui = require(script.Parent:WaitForChild("UiKit"))
local T, H, Images = Ui.Theme, Interface.Hud, Ui.Images
local Rewards = {}

local function block(parent: Instance, name: string, order: number, height: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name; frame.BackgroundTransparency = 1
	frame.LayoutOrder = order; frame.Size = UDim2.new(1, -4, 0, height)
	frame.Parent = parent
	return frame
end

local function amount(parent: Instance, image: string, value: string, color: Color3, x: number): Frame
	local item = Instance.new("Frame")
	item.BackgroundTransparency = 1
	item.Position = UDim2.new(0, x, 0.5, -24); item.Size = UDim2.fromOffset(110, 48)
	item.Parent = parent
	local icon = Ui.Icon(item, image, 44)
	icon.Position = UDim2.fromOffset(0, 2)
	local label = Ui.Heading(item, value, 24, color)
	label.Position = UDim2.fromOffset(50, 0); label.Size = UDim2.new(1, -50, 1, 0)
	return item
end

function Rewards.Render(parent: Instance, profile, send)
	local ready, day, nextAt = Rules.DailyStatus(profile, os.time())

	local hero = block(parent, "DailyHarvest", 1, 104)
	local gift = Ui.Icon(hero, Images.Rewards, 100)
	gift.Position = UDim2.fromOffset(10, 0)
	local heading = Ui.Heading(hero, if ready then "Your daily harvest" else "See you tomorrow!", 29)
	heading.Position = UDim2.fromOffset(132, 14); heading.Size = UDim2.new(1, -140, 0, 36)
	Ui.FitText(heading, 18, 29)
	local line = Ui.Heading(hero, if ready then "A little thank-you for tending your lawn." else "Today's gift is collected. Keep your streak growing.", 16)
	line.Position = UDim2.fromOffset(132, 54); line.Size = UDim2.new(1, -140, 0, 40)
	line.TextYAlignment = Enum.TextYAlignment.Top

	local week = block(parent, "Week", 2, H.RewardTile.Y)
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = week
	for index, coins in Tuning.DailyCoins do
		local today = index == day
		local tile = Ui.Surface(week, if today then T.TileActive else T.Tile, if today then T.TileActiveStroke else T.TileStroke, 13)
		tile.Name = "Day" .. index; tile.LayoutOrder = index
		local name = Ui.Heading(tile, "DAY " .. index, 13)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.Position = UDim2.fromOffset(0, 12); name.Size = UDim2.new(1, 0, 0, 20)
		local coin = Ui.Icon(tile, Images.Coin, 56)
		coin.AnchorPoint = Vector2.new(0.5, 0.5); coin.Position = UDim2.fromScale(0.5, 0.5)
		local value = Ui.Heading(tile, Format.Number(coins), 17)
		value.TextXAlignment = Enum.TextXAlignment.Center
		value.AnchorPoint = Vector2.new(0, 1)
		value.Position = UDim2.new(0, 0, 1, -8); value.Size = UDim2.new(1, 0, 0, 22)
	end
	local function arrange()
		local width = Ui.LocalWidth(week)
		local columns = if width >= 7 * (H.RewardTile.X + 4) then #Tuning.DailyCoins else 4
		local rows = math.ceil(#Tuning.DailyCoins / columns)
		local cell = math.min(H.RewardTile.X, (width - (columns - 1) * 8) / columns)
		grid.CellSize = UDim2.fromOffset(cell, H.RewardTile.Y)
		grid.CellPadding = UDim2.fromOffset(8, 8)
		grid.FillDirectionMaxCells = columns
		week.Size = UDim2.new(1, -4, 0, rows * H.RewardTile.Y + (rows - 1) * 8)
	end
	week:GetPropertyChangedSignal("AbsoluteSize"):Connect(arrange)
	arrange()

	local claimRow = block(parent, "Claim", 3, 52)
	amount(claimRow, Images.Coin, Format.Number(Tuning.DailyCoins[day]), T.Coins, 4)
	amount(claimRow, Images.Clover, tostring(Tuning.DailyClovers[day]), T.Clovers, 120)
	local claim = Ui.Button(claimRow, "ClaimDaily", "COLLECT TODAY'S GIFT", function() if ready then send("Daily") end end, "Green")
	claim.AnchorPoint = Vector2.new(1, 0.5); claim.Position = UDim2.new(1, -4, 0.5, 0)
	claim.Size = UDim2.new(1, -250, 0, 48)
	if not ready then
		Ui.Paint(claim, "Disabled", "NEXT GIFT IN " .. math.max(1, math.ceil((nextAt - os.time()) / 3600)) .. "H")
	end

	local waiting = profile.OfflineGrass > 0
	local offline = Ui.Surface(parent, T.Card, T.CardStroke, 14)
	offline.Name = "OfflineHarvest"; offline.LayoutOrder = 4
	offline.Size = UDim2.new(1, -4, 0, 148)
	local grass = Ui.Icon(offline, Images.Grass, 100)
	grass.AnchorPoint = Vector2.new(0, 0.5); grass.Position = UDim2.new(0, 14, 0.5, 0)
	local title = Ui.Heading(offline, "Your crew's harvest", 23)
	title.Position = UDim2.fromOffset(136, 20); title.Size = UDim2.new(1, -150, 0, 30)
	Ui.FitText(title, 16, 23)
	local detail = Ui.Heading(offline, if waiting then Format.Number(profile.OfflineGrass) .. " grass gathered while you were away." else "No offline harvest waiting.", 16)
	detail.Position = UDim2.fromOffset(136, 54); detail.Size = UDim2.new(1, -150, 0, 24)
	Ui.FitText(detail, 12, 16)
	local collect = Ui.Button(offline, "CollectOffline", "COLLECT GRASS", function() if waiting then send("CollectOffline") end end, if waiting then "Green" else "Muted")
	collect.Position = UDim2.fromOffset(136, 90); collect.Size = UDim2.new(1, -170, 0, 40)
	if not waiting then Ui.Paint(collect, "Muted", nil, false) end
end

return Rewards
