--!strict
-- Company Level on the HUD: a level badge with an XP bar at the bottom of
-- the screen, and the level-up celebration (spec: private-land-progression,
-- "level-ups are celebrated in the HUD"). Numbers come from the profile;
-- the curve from Shared/Config/CompanyLevel.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CompanyLevel = require(Shared.Config.CompanyLevel)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Format)
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local H = UiKit.Hud

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local playerGui = player:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("LevelHud")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "LevelHud"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.DisplayOrder = 2
gui.Parent = playerGui
-- Menus cover the HUD; the level bar would peek out under the window.
UiKit.MenuChanged:Connect(function(open) gui.Enabled = not open end)

-- Level badge + XP bar ------------------------------------------------------------

local BAR_WIDTH = 300
local BAR_HEIGHT = 24
local BADGE = 58

local holder = Instance.new("Frame")
holder.Name = "Level"
holder.AnchorPoint = Vector2.new(0.5, 1)
holder.Position = UDim2.new(0.5, 0, 1, -12)
holder.Size = UDim2.fromOffset(BAR_WIDTH + BADGE / 2, BADGE)
holder.BackgroundTransparency = 1
holder.Parent = gui
do
	-- Phones: keep the widget inside narrow screens.
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	-- Big screens: top center. Phones: bottom center, the top row holds
	-- Coins/Clovers/storage there.
	local function fit()
		scale.Scale = math.clamp(gui.AbsoluteSize.X / 560, 0.7, 1)
		local compact = UiKit.IsCompact(gui.AbsoluteSize)
		holder.AnchorPoint = Vector2.new(0.5, if compact then 1 else 0)
		-- On phones it rides above Roblox's tool hotbar.
		holder.Position = if compact then UDim2.new(0.5, 0, 1, -H.CoreHotbarHeight) else UDim2.new(0.5, 0, 0, 12)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
end

-- The bar starts under the badge's center and sits on the bottom edge;
-- the labels ride on top of it.
local bar = UiKit.ProgressBar(holder, UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT))
bar.Frame.AnchorPoint = Vector2.new(0, 1)
bar.Frame.Position = UDim2.new(0, BADGE / 2, 1, -4)

local title = UiKit.OutlinedText(holder, "Company Level", 16)
title.AnchorPoint = Vector2.new(0, 1)
title.Position = UDim2.new(0, BADGE + 6, 1, -BAR_HEIGHT - 8)

local xpText = UiKit.OutlinedText(holder, "", 16)
xpText.AnchorPoint = Vector2.new(1, 1)
xpText.Position = UDim2.new(0, BADGE / 2 + BAR_WIDTH - 6, 1, -BAR_HEIGHT - 8)

-- Round badge over the bar's left end.
local badge = UiKit.Card(holder, 999)
badge.Name = "Badge"
badge.AnchorPoint = Vector2.new(0.5, 0.5)
badge.Position = UDim2.new(0, BADGE / 2, 0.5, 0)
badge.Size = UDim2.fromOffset(BADGE - 6, BADGE - 6)
badge.BackgroundColor3 = UiKit.Colors.Gold
badge.ZIndex = 5
local badgeScale = Instance.new("UIScale")
badgeScale.Parent = badge
local levelText = UiKit.OutlinedText(badge, "1", 28)
levelText.AnchorPoint = Vector2.new(0.5, 0.5)
levelText.Position = UDim2.fromScale(0.5, 0.5)
levelText.ZIndex = 6

local shownLevel: number? = nil

local function refresh(profile)
	local level: number = profile.Level or 1
	local needed = CompanyLevel.XpToNext(level)
	local maxed = needed == math.huge
	levelText.Text = tostring(level)
	xpText.Text = if maxed then "MAX" else ("%s / %s XP"):format(Format.Number(profile.Xp or 0), Format.Number(needed))
	-- A new level starts the bar from empty instead of sliding backwards.
	if shownLevel ~= nil and level > shownLevel then
		bar.Set(0, false)
	end
	bar.Set(if maxed then 1 else (profile.Xp or 0) / needed, shownLevel ~= nil)
	shownLevel = level
end

ClientState.Changed:Connect(refresh)
if ClientState.Get() then
	refresh(ClientState.Get())
end

-- Level-up celebration ------------------------------------------------------------

local CONFETTI = { UiKit.Colors.Gold, UiKit.Colors.Green, UiKit.Colors.Coral, UiKit.Colors.Cream, UiKit.Colors.Leaf }
local rng = Random.new()

local function confetti(parent: Instance, count: number)
	for _ = 1, count do
		local piece = Instance.new("Frame")
		local size = rng:NextInteger(8, 14)
		piece.Size = UDim2.fromOffset(size, size * rng:NextNumber(0.5, 1))
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.fromScale(0.5, 0.3)
		piece.Rotation = rng:NextInteger(0, 360)
		piece.BackgroundColor3 = CONFETTI[rng:NextInteger(1, #CONFETTI)]
		piece.BorderSizePixel = 0
		piece.ZIndex = 8
		piece.Parent = parent
		UiKit.Corner(piece, 3)
		UiKit.Stroke(piece, 1.5)
		-- Burst outward, then fall.
		local burst = Vector2.new(rng:NextNumber(-0.32, 0.32), rng:NextNumber(-0.2, 0.05))
		local time = rng:NextNumber(1.3, 2.1)
		TweenService:Create(piece, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5 + burst.X, 0.3 + burst.Y + 0.55),
			Rotation = piece.Rotation + rng:NextInteger(-540, 540),
		}):Play()
		TweenService:Create(piece, TweenInfo.new(0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, time - 0.4), {
			BackgroundTransparency = 1,
		}):Play()
		task.delay(time, function()
			piece:Destroy()
		end)
	end
end

local celebrationToken = 0

local function celebrate(level: number)
	celebrationToken += 1
	local token = celebrationToken
	local previous = gui:FindFirstChild("LevelUp")
	if previous then
		previous:Destroy()
	end

	local root = Instance.new("Frame")
	root.Name = "LevelUp"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui

	local stack = Instance.new("Frame")
	stack.AnchorPoint = Vector2.new(0.5, 0.5)
	stack.Position = UDim2.fromScale(0.5, 0.3)
	stack.Size = UDim2.fromOffset(0, 0)
	stack.AutomaticSize = Enum.AutomaticSize.XY
	stack.BackgroundTransparency = 1
	stack.ZIndex = 9
	stack.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = stack
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = stack

	local big = math.clamp(gui.AbsoluteSize.X / 12, 40, 72)
	local heading = UiKit.OutlinedText(stack, "LEVEL UP!", big, UiKit.Colors.Gold)
	heading.LayoutOrder = 1
	heading.ZIndex = 9
	local sub = UiKit.OutlinedText(stack, ("Company Level %d"):format(level), big * 0.45)
	sub.LayoutOrder = 2
	sub.ZIndex = 9
	-- Tell the player when this level opens the way to new land.
	for _, zone in Zones.List do
		if zone.RequiredLevel == level and zone.UnlockPrice > 0 then
			local unlock = UiKit.OutlinedText(stack, zone.DisplayName .. " can now be unlocked", big * 0.36, UiKit.Colors.Leaf)
			unlock.LayoutOrder = 3
			unlock.ZIndex = 9
		end
	end

	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	confetti(root, 36)

	-- The badge bumps with it.
	badgeScale.Scale = 1.5
	TweenService:Create(badgeScale, TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	task.delay(2.6, function()
		if celebrationToken ~= token or not root.Parent then
			return
		end
		local out = TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
		out:Play()
		out.Completed:Wait()
		if celebrationToken == token then
			root:Destroy()
		end
	end)
end

(remotes:WaitForChild("LevelUp") :: RemoteEvent).OnClientEvent:Connect(celebrate)
