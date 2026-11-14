--!strict
-- Boat travel on the client (Shared/Config/Travel.luau; the server checks
-- every trip: TravelService). Each jetty the local player may use gets a
-- prompt by its boat:
--   * on an island they unlocked: "Sail home" (to their own base);
--   * on their base: "Sail to an island", which opens a small list of the
--     islands they have unlocked.
-- While the server carries the character over, the screen shows the sea
-- and where the boat is going.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Travel)
local Zones = require(Shared.Config.Zones)
local Jetties = require(Shared.Jetties)

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local Ui = require(script.Parent:WaitForChild("UiKit"))

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Travel") :: RemoteEvent
local T = Ui.Theme

-- The picker: islands to sail to from the base ----------------------------------------

local gui = Ui.LocalGui("BoatTravel", 20)
local picker = Ui.Surface(gui, T.Surface, T.SurfaceStroke, 18, 3)
picker.Name = "Picker"
picker.AnchorPoint = Vector2.new(0.5, 0.5)
picker.Position = UDim2.fromScale(0.5, 0.5)
picker.Visible = false
Ui.AutoScale(gui, picker)
Ui.ManagePanel(picker)
local title = Ui.Heading(picker, Config.PickerTitle, 26)
title.Position = UDim2.fromOffset(18, 12)
title.Size = UDim2.new(1, -36, 0, 34)
local list = Instance.new("Frame")
list.Name = "List"
list.BackgroundTransparency = 1
list.Position = UDim2.fromOffset(18, 54)
list.Size = UDim2.new(1, -36, 1, -72)
list.Parent = picker
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local function openPicker()
	local profile = ClientState.Get()
	if not profile then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local rows = 0
	for index, zone in Zones.List do
		if Jetties.Destination(player.UserId, profile.UnlockedZoneIds, zone.Id) then
			rows += 1
			local button = Ui.Button(list, zone.Id, zone.DisplayName:upper(), function()
				picker.Visible = false
				remote:FireServer(zone.Id)
			end, "Blue")
			button.LayoutOrder = index
		end
	end
	if rows == 0 then
		rows = 1
		local none = Ui.Button(list, "None", "UNLOCK AN ISLAND FIRST", function() end, "Disabled")
		none.LayoutOrder = 1
	end
	picker.Size = UDim2.fromOffset(340, 72 + rows * (Ui.Hud.ButtonHeight + 8))
	Ui.OpenPanel(picker)
end

-- Prompts on the jetties --------------------------------------------------------------

local folder = Instance.new("Folder")
folder.Name = "BoatTravel (local)"
folder.Parent = Workspace
local points: { [string]: { Jetty: Model, Part: BasePart } } = {}

local function refresh()
	local profile = ClientState.Get()
	local usable = if profile then Jetties.Usable(player.UserId, profile.UnlockedZoneIds) else {}
	for name, point in points do
		if usable[name] ~= point.Jetty then
			point.Part:Destroy()
			points[name] = nil
		end
	end
	for name, jetty in usable do
		if not points[name] then
			local part = Instance.new("Part")
			part.Name = name
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Transparency = 1
			part.Size = Vector3.one
			-- At the end of the deck, by the boat.
			local pivot = jetty:GetPivot()
			part.CFrame = pivot * CFrame.new(0, 3, -Config.Jetty.Length * 0.3)
			local prompt = Instance.new("ProximityPrompt")
			prompt.ObjectText = Config.ObjectText
			prompt.ActionText = if name == Jetties.Home then Config.AwayAction else Config.HomeAction
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0.3
			prompt.MaxActivationDistance = Config.Distance - 2
			prompt.RequiresLineOfSight = false
			prompt.Triggered:Connect(function()
				if name == Jetties.Home then
					openPicker()
				else
					remote:FireServer(Jetties.Home)
				end
			end)
			prompt.Parent = part
			part.Parent = folder
			points[name] = { Jetty = jetty, Part = part }
		end
	end
end

ClientState.Changed:Connect(refresh)
-- Bases are handed out, and jetties may stream in, after the profile came.
task.spawn(function()
	while true do
		refresh()
		task.wait(2)
	end
end)

-- The trip ------------------------------------------------------------------------------

local curtain = Instance.new("Frame")
curtain.Name = "Sea"
curtain.BackgroundColor3 = Config.Sea
curtain.BackgroundTransparency = 1
curtain.BorderSizePixel = 0
curtain.Size = UDim2.fromScale(1, 1)
curtain.ZIndex = 10
curtain.Visible = false
curtain.Parent = gui
local where = Ui.OutlinedText(curtain, "", 34)
where.AnchorPoint = Vector2.new(0.5, 0.5)
where.Position = UDim2.fromScale(0.5, 0.5)
where.Size = UDim2.new(0.8, 0, 0, 60)
where.TextXAlignment = Enum.TextXAlignment.Center
where.TextTransparency = 1
where.ZIndex = 11
local outline = where:FindFirstChildOfClass("UIStroke") :: UIStroke
outline.Transparency = 1

remote.OnClientEvent:Connect(function(destination: string, seconds: number)
	local zone = Zones.ById[destination]
	where.Text = Config.Sailing:format(if zone then zone.DisplayName else Config.HomeName)
	curtain.Visible = true
	local half = seconds / 2
	local fade = TweenInfo.new(half * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(curtain, fade, { BackgroundTransparency = 0 }):Play()
	TweenService:Create(where, fade, { TextTransparency = 0 }):Play()
	TweenService:Create(outline, fade, { Transparency = 0 }):Play()
	task.wait(half + 0.25)
	local clear = TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(curtain, clear, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(outline, clear, { Transparency = 1 }):Play()
	local last = TweenService:Create(where, clear, { TextTransparency = 1 })
	last.Completed:Once(function()
		curtain.Visible = false
	end)
	last:Play()
end)
