--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Config.Progression)
local Interface = require(Shared.Config.Interface)
local Format = require(Shared.Format)
local Rules = require(Shared.ProgressionRules)
local Ui = require(script.Parent:WaitForChild("UiKit"))
local Rewards = {}
local function label(parent, value, size, x, y, width, height)
	local item = Ui.Text(parent, value, size)
	item.Position = UDim2.fromOffset(x, y)
	item.Size = UDim2.new(1, -width, 0, height)
	return item
end
function Rewards.Render(parent: Instance, profile, send)
	local ready, day, nextAt = Rules.DailyStatus(profile, os.time())
	local sheet = Instance.new("Frame")
	sheet.Name = "DailyHarvest"; sheet.BackgroundTransparency = 1
	sheet.Size = UDim2.new(1, 0, 0, 266); sheet.LayoutOrder = 1; sheet.Parent = parent
	local heading = label(sheet, if ready then "Your daily harvest" else "See you tomorrow!", 23, 4, 0, 8, 30)
	heading.FontFace = Ui.Font
	label(sheet, if ready then "A little thank-you for tending your lawn." else "Today's reward is collected. Keep your streak growing.", 14, 4, 35, 8, 34)
	local days = Instance.new("Frame")
	days.Name = "Week"; days.BackgroundTransparency = 1
	days.Position = UDim2.fromOffset(4, 74); days.Size = UDim2.new(1, -8, 0, Interface.Hud.RewardDayHeight)
	days.Parent = sheet
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(1 / #Tuning.DailyCoins, -6, 1, 0)
	grid.CellPadding = UDim2.fromOffset(6, 0)
	grid.FillDirectionMaxCells = #Tuning.DailyCoins; grid.SortOrder = Enum.SortOrder.LayoutOrder; grid.Parent = days
	for index, amount in Tuning.DailyCoins do
		local current = index == day
		local tile = Instance.new("Frame")
		tile.Name = "Day" .. index; tile.LayoutOrder = index
		tile.BackgroundColor3 = if current then Ui.Colors.Leaf else Ui.Colors.Track
		tile.Parent = days
		Ui.Corner(tile, 12); Ui.Stroke(tile, if current then 2 else 1, if current then Ui.Colors.GreenShade else Ui.Colors.CreamShade)
		local name = label(tile, "Day " .. index, 13, 0, 7, 0, 20)
		name.TextXAlignment = Enum.TextXAlignment.Center
		local image = Ui.Icon(tile, Interface.Images.Coin, 40)
		image.Position = UDim2.new(0.5, -20, 0, 29)
		local value = label(tile, Format.Number(amount), 15, 0, 73, 0, 23)
		value.TextXAlignment = Enum.TextXAlignment.Center; value.FontFace = Ui.Font
	end
	local coins = Ui.Resource(sheet, "DailyCoins", Interface.Images.Coin, 128, 32)
	coins.Frame.Position = UDim2.fromOffset(4, 193); coins.Value.Text = Format.Number(Tuning.DailyCoins[day]); coins.Value.TextColor3 = Ui.Colors.Ink
	local clovers = Ui.Resource(sheet, "DailyClovers", Interface.Images.Clover, 108, 32)
	clovers.Frame.Position = UDim2.fromOffset(134, 193); clovers.Value.Text = tostring(Tuning.DailyClovers[day]); clovers.Value.TextColor3 = Ui.Colors.Ink
	Ui.PlainValue(coins.Value); Ui.PlainValue(clovers.Value)
	local claim = Ui.Button(sheet, "ClaimDaily", if ready then "Collect today's gift" else "Collected · " .. math.max(1, math.ceil((nextAt - os.time()) / 3600)) .. "h to next gift", function() if ready then send("Daily") end end)
	claim.AnchorPoint = Vector2.new(1, 0); claim.Position = UDim2.new(1, -4, 0, 191)
	claim.Size = UDim2.new(0.52, 0, 0, 44)
	claim.BackgroundColor3 = if ready then Ui.Colors.Green else Ui.Colors.Track
	claim.TextSize = 14
	claim.Selectable = ready; claim.Active = ready; claim.AutoButtonColor = ready
	-- The claim gets its own row; currencies must never sit under the button.
	local function arrange()
		local columns = if sheet.AbsoluteSize.X >= 490 then #Tuning.DailyCoins else 4
		local rows = math.ceil(#Tuning.DailyCoins / columns)
		local height = rows * Interface.Hud.RewardDayHeight + (rows - 1) * 8
		grid.FillDirectionMaxCells = columns
		grid.CellSize = UDim2.new(1 / columns, -6, 0, Interface.Hud.RewardDayHeight)
		grid.CellPadding = UDim2.fromOffset(6, 8)
		days.Size = UDim2.new(1, -8, 0, height)
		coins.Frame.Position = UDim2.fromOffset(4, 86 + height)
		clovers.Frame.Position = UDim2.fromOffset(134, 86 + height)
		claim.Position = UDim2.new(1, -4, 0, 130 + height)
		claim.Size = UDim2.new(1, -8, 0, 44)
		sheet.Size = UDim2.new(1, 0, 0, height + 202)
	end
	sheet:GetPropertyChangedSignal("AbsoluteSize"):Connect(arrange)
	arrange()
	local line = Instance.new("Frame")
	line.BackgroundColor3 = Ui.Colors.CreamShade; line.BorderSizePixel = 0
	line.Position = UDim2.new(0, 4, 1, -12); line.Size = UDim2.new(1, -8, 0, 1); line.Parent = sheet
	local offline = Instance.new("Frame")
	offline.Name = "OfflineHarvest"; offline.BackgroundTransparency = 1
	offline.LayoutOrder = 2; offline.Size = UDim2.new(1, 0, 0, 140); offline.Parent = parent
	local image = Ui.Icon(offline, Interface.Images.Grass, 64)
	image.Position = UDim2.fromOffset(4, 4)
	label(offline, "Your crew's harvest", 20, 80, 0, 88, 30).FontFace = Ui.Font
	label(offline, Format.Number(profile.OfflineGrass) .. " grass gathered while you were away", 14, 80, 35, 88, 26)
	local collect = Ui.Button(offline, "CollectOffline", if profile.OfflineGrass > 0 then "Collect grass" else "No harvest waiting", function() if profile.OfflineGrass > 0 then send("CollectOffline") end end)
	collect.Position = UDim2.fromOffset(80, 76); collect.Size = UDim2.new(1, -88, 0, 44)
	collect.BackgroundColor3 = if profile.OfflineGrass > 0 then Ui.Colors.Gold else Ui.Colors.Track
	collect.AutoButtonColor = profile.OfflineGrass > 0; collect.Active = profile.OfflineGrass > 0; collect.Selectable = profile.OfflineGrass > 0
	if profile.OfflineGrass == 0 then
		label(offline, "Station crew on your land with automation to grow an offline harvest.", 13, 4, 126, 8, 40)
		offline.Size = UDim2.new(1, 0, 0, 174)
	end
end
return Rewards
