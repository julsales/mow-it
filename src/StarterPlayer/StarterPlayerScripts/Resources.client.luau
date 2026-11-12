--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Interface = require(Shared.Config.Interface)
local Weather = require(Shared.Config.Weather)
local GrassBag = require(Shared.GrassBag)
local Format = require(Shared.Format)
local State = require(script.Parent:WaitForChild("ClientState"))
local Ui = require(script.Parent:WaitForChild("UiKit"))
local H = Interface.Hud
local gui = Instance.new("ScreenGui")
gui.Name = "Resources"; gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local resources = Instance.new("Frame")
resources.Name = "Indicators"; resources.BackgroundTransparency = 1
resources.AnchorPoint = Vector2.new(1, 0)
resources.Position = UDim2.new(1, -H.Edge, 0, 6)
resources.Size = UDim2.fromOffset(H.ResourceWidth / 2, H.ResourceRow * 2)
resources.Parent = gui
local function indicator(name, image, x, y)
	local item = Ui.Resource(resources, name, image, H.ResourceWidth / 2, H.IconSize)
	item.Frame.Position = UDim2.fromOffset(x, y)
	return item
end
local sky = indicator("Weather", Interface.Images.Weather.clear, 0, 0)
local fuel = indicator("Fuel", Interface.Images.Fuel, 0, H.ResourceRow)
local coins = Ui.Resource(gui, "Coins", Interface.Images.Coin, 184, H.CurrencyIcon, H.CurrencyText)
local clovers = Ui.Resource(gui, "Clovers", Interface.Images.Clover, 184, H.CurrencyIcon, H.CurrencyText)
coins.Value.TextColor3 = Ui.Colors.Gold
clovers.Value.TextColor3 = Ui.Colors.Leaf
local grass = Ui.Resource(gui, "Storage", Interface.Images.Grass, 220, 38)
grass.Frame.AnchorPoint = Vector2.new(0, 1)
grass.Frame.Position = UDim2.new(0, H.Edge, 1, -72)
local weatherName = Ui.OutlinedText(gui, "", 14)
weatherName.Name = "WeatherName"; weatherName.Visible = false
weatherName.AnchorPoint = Vector2.new(1, 0)
weatherName.Position = UDim2.new(1, -H.Edge, 0, H.ResourceRow * 2)
local hit = Instance.new("TextButton")
hit.Name = "WeatherInfo"; hit.Text = ""; hit.BackgroundTransparency = 1
hit.Size = UDim2.new(1, 0, 1, 0); hit.Parent = sky.Frame
hit.MouseEnter:Connect(function() weatherName.Visible = true end)
hit.MouseLeave:Connect(function() weatherName.Visible = false end)
hit.Activated:Connect(function() weatherName.Visible = not weatherName.Visible end)
local function update()
	gui.Enabled = not Ui.MenuOpen
	local profile = State.Get()
	local id = workspace:GetAttribute("WeatherId") or "clear"
	local weather = Weather.ById[id] or Weather.ById.clear
	sky.Icon.Image = Interface.Images.Weather[id] or Interface.Images.Weather.clear
	weatherName.Text = weather.DisplayName
	local seconds = math.max(0, math.ceil((workspace:GetAttribute("WeatherEndsAt") or 0) - workspace:GetServerTimeNow()))
	sky.Value.Text = string.format("%d:%02d", seconds // 60, seconds % 60)
	if not profile then return end
	coins.Value.Text = Format.Number(profile.Coins)
	clovers.Value.Text = Format.Number(profile.Clovers)
	fuel.Value.Text = math.floor(profile.Fuel) .. "%"
	grass.Value.Text = Format.Number(GrassBag.Total(profile)) .. "/" .. Format.Number(GrassBag.Capacity(profile))
	local compact = gui.AbsoluteSize.Y < H.CompactHeight
	local navPosition, navSize = Ui.NavigationLayout(gui.AbsoluteSize)
	local iconSize = if compact then H.CompactCurrencyIcon else H.CurrencyIcon
	for index, item in { coins, clovers } do
		item.Frame.Position = UDim2.fromOffset(navPosition.X.Offset, navPosition.Y.Offset + navSize.Y + H.CurrencyGap + (index - 1) * iconSize)
		item.Frame.Size = UDim2.fromOffset(if compact then 148 else 200, iconSize)
		item.Icon.Size = UDim2.fromOffset(iconSize, iconSize)
		item.Value.Position = UDim2.fromOffset(iconSize + 4, 0)
		item.Value.Size = UDim2.new(1, -iconSize - 4, 1, 0);
		(item.Value:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint).MaxTextSize = if compact then H.CompactCurrencyText else H.CurrencyText
	end
	grass.Frame.Position = if compact then UDim2.new(0.5, -90, 1, -66) else UDim2.new(0, H.Edge, 1, -72)
	grass.Frame.Size = UDim2.fromOffset(if compact then 180 else 220, H.IconSize)
end
State.Changed:Connect(update)
Ui.MenuChanged:Connect(update)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
task.spawn(function() while gui.Parent do update(); task.wait(1) end end)
