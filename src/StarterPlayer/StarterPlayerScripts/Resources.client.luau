--!strict
-- HUD readouts from board 1: weather timer and fuel top right, Coins and
-- Clovers under the menu tiles, grass storage bottom left. Positions are
-- board pixels; UiKit.AutoScale shrinks each group on short screens.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Weather = require(Shared.Config.Weather)
local GrassBag = require(Shared.GrassBag)
local Format = require(Shared.Format)
local State = require(script.Parent:WaitForChild("ClientState"))
local Ui = require(script.Parent:WaitForChild("UiKit"))
local H, T, Images = Ui.Hud, Ui.Theme, Ui.Images

local gui = Ui.LocalGui("Resources")

local function group(name: string, anchor: Vector2, position: UDim2, size: Vector2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name; frame.BackgroundTransparency = 1
	frame.AnchorPoint = anchor; frame.Position = position
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.Parent = gui
	Ui.AutoScale(gui, frame)
	return frame
end

-- Top right: weather (icon + time left) over fuel.
local status = group("Status", Vector2.new(1, 0), UDim2.new(1, -H.Edge, 0, 0), Vector2.new(H.Status.X + 8, H.Top + H.Status.Y * 2 + H.StatusGap))
local function statusPill(name: string, image: string, row: number): Ui.Pill
	local pill = Ui.Pill(status, name, image, H.Status, H.StatusIcon, H.StatusText)
	pill.Frame.AnchorPoint = Vector2.new(1, 0)
	pill.Frame.Position = UDim2.new(1, 0, 0, H.Top + row * (H.Status.Y + H.StatusGap))
	return pill
end
local sky = statusPill("Weather", Images.Weather.clear, 0)
local fuel = statusPill("Fuel", Images.Fuel, 1)

-- Left rail: currencies sit under the 2x2 menu tiles (Operations).
-- Compact (phones): one row at the top center with the storage pill.
local rail = group("Currencies", Vector2.zero, UDim2.fromOffset(0, 0), Vector2.new(0, 0))
local function currency(name: string, image: string, color: Color3): Ui.Pill
	return Ui.Pill(rail, name, image, H.Pill, H.PillIcon, H.PillText, color)
end
local coins = currency("Coins", Images.Coin, T.Coins)
local clovers = currency("Clovers", Images.Clover, T.Clovers)

-- Bottom left: grass in storage / capacity.
local bottom = group("Storage", Vector2.new(0, 1), UDim2.new(0, 0, 1, -H.Edge), Vector2.new(H.Storage.X + 40, H.Storage.Y))
local grass = Ui.Pill(bottom, "Storage", Images.Grass, H.Storage, H.StorageIcon, H.StorageText)

local function arrange()
	local compact = Ui.IsCompact(gui.AbsoluteSize)
	local overhang = math.round((H.PillIcon - H.Pill.Y) * 0.75) + 6
	if compact then
		local slot = H.CompactPillWidth + overhang + 8
		rail.AnchorPoint = Vector2.new(0.5, 0); rail.Position = UDim2.fromScale(0.5, 0)
		rail.Size = UDim2.fromOffset(slot * 3, H.Pill.Y + 8)
		for index, pill in { coins, clovers, grass } do
			pill.Frame.Parent = rail
			pill.Frame.Size = UDim2.fromOffset(H.CompactPillWidth, H.Pill.Y)
			pill.Frame.Position = UDim2.fromOffset(overhang + (index - 1) * slot, 4)
		end
		bottom.Visible = false
	else
		rail.AnchorPoint = Vector2.zero; rail.Position = UDim2.fromOffset(0, 0)
		rail.Size = UDim2.fromOffset(H.Pill.X + 40, H.RailTop + 2 * (H.Tile + H.TileGap) + 2 * (H.Pill.Y + H.PillGap))
		for index, pill in { coins, clovers } do
			pill.Frame.Size = UDim2.fromOffset(H.Pill.X, H.Pill.Y)
			pill.Frame.Position = UDim2.fromOffset(H.Edge + 10, H.RailTop + 2 * (H.Tile + H.TileGap) + 19 + (index - 1) * (H.Pill.Y + H.PillGap))
		end
		grass.Frame.Parent = bottom
		grass.Frame.Size = UDim2.fromOffset(H.Storage.X, H.Storage.Y)
		grass.Frame.Position = UDim2.fromOffset(H.Edge + 10, 0)
		bottom.Visible = true
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(arrange)
arrange()

local weatherName = Ui.OutlinedText(status, "", 15)
weatherName.Name = "WeatherName"; weatherName.Visible = false
weatherName.AnchorPoint = Vector2.new(1, 0)
weatherName.Position = UDim2.new(1, -4, 0, H.Top + 2 * (H.Status.Y + H.StatusGap) - 4)
local hit = Instance.new("TextButton")
hit.Name = "WeatherInfo"; hit.Text = ""; hit.BackgroundTransparency = 1
hit.Size = UDim2.fromScale(1, 1); hit.Parent = sky.Frame
hit.MouseEnter:Connect(function() weatherName.Visible = true end)
hit.MouseLeave:Connect(function() weatherName.Visible = false end)
hit.Activated:Connect(function() weatherName.Visible = not weatherName.Visible end)

local function update()
	gui.Enabled = not Ui.MenuOpen
	local id = workspace:GetAttribute("WeatherId") or "clear"
	local weather = Weather.ById[id] or Weather.ById.clear
	sky.Icon.Image = Images.Weather[id] or Images.Weather.clear
	weatherName.Text = weather.DisplayName
	local seconds = math.max(0, math.ceil((workspace:GetAttribute("WeatherEndsAt") or 0) - workspace:GetServerTimeNow()))
	sky.Value.Text = string.format("%d:%02d", seconds // 60, seconds % 60)
	local profile = State.Get()
	if not profile then return end
	coins.Value.Text = Format.Number(profile.Coins)
	clovers.Value.Text = Format.Number(profile.Clovers)
	fuel.Value.Text = math.floor(profile.Fuel) .. "%"
	grass.Value.Text = Format.Number(GrassBag.Total(profile)) .. " / " .. Format.Number(GrassBag.Capacity(profile))
end
State.Changed:Connect(update)
Ui.MenuChanged:Connect(update)
task.spawn(function() while gui.Parent do update(); task.wait(1) end end)
