--!strict
-- Mow It! client: input (click/tap to cut) + a FUNCTIONAL placeholder HUD.
-- The final UI comes from ready-made kits (docs/ASSETS.md > UI). This HUD
-- is intentionally plain: it proves the loop and gives the UI kit real
-- data/bindings to replace, widget by widget. Do not polish this file —
-- replace it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Tools = require(Shared.Config.Tools)
local Backpacks = require(Shared.Config.Backpacks)
local Zones = require(Shared.Config.Zones)
local GrassTypes = require(Shared.Config.GrassTypes)
local GrassBag = require(Shared.GrassBag)

local LandState = require(script.Parent:WaitForChild("LandState"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local profile: any = nil

-- HUD -----------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "MowItHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(name: string, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundColor3 = Color3.fromRGB(20, 30, 20)
	label.BackgroundTransparency = 0.3
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = name
	label.Parent = gui
	return label
end

local coinsLabel = makeLabel("Coins", UDim2.new(0, 10, 0, 10), UDim2.new(0, 220, 0, 40))
local grassLabel = makeLabel("Grass", UDim2.new(0, 10, 0, 56), UDim2.new(0, 220, 0, 40))
local toolLabel = makeLabel("Tool", UDim2.new(0, 10, 0, 102), UDim2.new(0, 220, 0, 40))
local notifyLabel = makeLabel("", UDim2.new(0.5, -250, 0, 10), UDim2.new(0, 500, 0, 40))
notifyLabel.BackgroundTransparency = 1

local function makeButton(name: string, text: string, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = UDim2.new(0, 160, 0, 44)
	button.BackgroundColor3 = Color3.fromRGB(46, 120, 60)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.Parent = gui
	return button
end

-- Placeholder shop: cycles to the NEXT tool/backpack/zone. The real shop
-- is a scrolling list built from the same configs (Phase 3 in the plan).
local nextToolButton = makeButton("NextTool", "Next Tool", UDim2.new(1, -170, 0, 10))
local nextPackButton = makeButton("NextPack", "Next Storage", UDim2.new(1, -170, 0, 60))
-- Tools and storage are bought in the Shop panel (Shop.client.luau) now;
-- land expansions at their gate (refreshGates below).
nextToolButton.Visible = false
nextPackButton.Visible = false
-- No on-screen SELL button: selling happens by walking onto a sell stall's
-- pad (SellGuide.client.luau points the way when storage is full). The
-- SellRequest remote stays for a future "Sell Anywhere" pass / Auto-Sell.

local function nextUnowned(list, owned: { [string]: boolean })
	for _, def in list do
		if not owned[def.Id] then
			return def
		end
	end
	return nil
end

local function refresh()
	if not profile then
		return
	end
	local tool = Tools.ById[profile.EquippedToolId]
	coinsLabel.Text = "$ " .. Format.Number(profile.Coins)
	-- Total carried; special variants are listed after it ("+3 Golden Grass").
	local carried = ("🌿 %s / %s"):format(Format.Number(GrassBag.Total(profile)), Format.Number(GrassBag.Capacity(profile)))
	for variantId, count in profile.GrassByVariant do
		if variantId ~= GrassBag.DefaultVariant and count > 0 then
			local def = GrassTypes.ById[variantId]
			carried ..= (" +%s %s"):format(Format.Number(count), if def then def.DisplayName else variantId)
		end
	end
	grassLabel.Text = carried
	toolLabel.Text = tool and tool.DisplayName or "?"

	local nextTool = nextUnowned(Tools.List, profile.OwnedToolIds)
	nextToolButton.Text = nextTool and ("Tool: " .. nextTool.DisplayName .. " (" .. Format.Number(nextTool.Price) .. ")") or "Tools MAX"
	local nextPack = nextUnowned(Backpacks.List, profile.OwnedBackpackIds)
	nextPackButton.Text = nextPack and ("Storage: " .. nextPack.DisplayName .. " (" .. Format.Number(nextPack.Price) .. ")") or "Storage MAX"
end

nextToolButton.Activated:Connect(function()
	local nextTool = profile and nextUnowned(Tools.List, profile.OwnedToolIds)
	if nextTool then
		(remotes:WaitForChild("BuyTool") :: RemoteEvent):FireServer(nextTool.Id)
	end
end)
nextPackButton.Activated:Connect(function()
	local nextPack = profile and nextUnowned(Backpacks.List, profile.OwnedBackpackIds)
	if nextPack then
		(remotes:WaitForChild("BuyBackpack") :: RemoteEvent):FireServer(nextPack.Id)
	end
end)

-- Cutting input: click / tap / controller trigger. Auto-Swing buff turns
-- this into hold-to-mow on the client; the server still rate-limits.
local autoSwingHeld = false
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		autoSwingHeld = true;
		(remotes:WaitForChild("CutRequest") :: RemoteEvent):FireServer()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		autoSwingHeld = false
	end
end)
task.spawn(function()
	while true do
		task.wait(0.15)
		if autoSwingHeld and profile and (profile.BuffStacks or {}).auto_swing then
			(remotes:WaitForChild("CutRequest") :: RemoteEvent):FireServer()
		end
	end
end);

-- Server pushes ----------------------------------------------------------------
-- Zone gates (Workspace/Zones/<id>/ZoneGate) are solid on the server.
-- Each client opens the gates of the expansions unlocked on the land of
-- this session (the host's, LandState). The server still refuses cutting
-- in locked expansions.
--
-- The gate's "Unlock" prompt (Map/Gates on the server) is painted here for
-- this player: what it costs, or what is still missing.
local function paintGatePrompt(gate: BasePart, zone, open: boolean)
	local prompt = gate:FindFirstChild("ZoneGatePrompt", true)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end
	local nextZone = Zones.NextLocked(LandState.Unlocked())
	prompt.Enabled = not open
	prompt.ObjectText = zone.DisplayName
	if not LandState.IsHost() then
		prompt.ActionText = ("Only %s can expand this land"):format(LandState.HostName())
	elseif nextZone and nextZone.Id ~= zone.Id then
		prompt.ActionText = "Unlock " .. nextZone.DisplayName .. " first"
	elseif (profile.Level or 1) < zone.RequiredLevel then
		prompt.ActionText = ("Needs Company Level %d"):format(zone.RequiredLevel)
	else
		prompt.ActionText = "Unlock · " .. Format.Coins(zone.UnlockPrice)
	end
end

local function refreshGates()
	local zonesFolder = workspace:FindFirstChild("Zones")
	if not zonesFolder or not profile then
		return
	end
	for _, zone in Zones.List do
		local folder = zonesFolder:FindFirstChild(zone.Id)
		local gate = folder and folder:FindFirstChild("ZoneGate")
		if gate and gate:IsA("BasePart") then
			local open = LandState.IsUnlocked(zone.Id)
			paintGatePrompt(gate, zone, open)
			gate.CanCollide = not open
			gate.Transparency = if open then 1 else 0.3
			for _, child in gate:GetChildren() do
				if child:IsA("SurfaceGui") then
					child.Enabled = not open
				end
			end
		end
		-- Invisible walls above the fences of this zone (MapService): they
		-- stop jumping in until the zone is unlocked.
		if folder then
			local open = LandState.IsUnlocked(zone.Id)
			for _, child in folder:GetChildren() do
				if child.Name == "ZoneWall" and child:IsA("BasePart") then
					child.CanCollide = not open
				end
			end
		end
	end
end

-- With streaming, gates/walls can arrive (or come back) after the profile
-- did. Many arrive at once, so refresh once per frame at most.
local refreshQueued = false
workspace.DescendantAdded:Connect(function(instance)
	local name = instance.Name
	if (name == "ZoneGate" or name == "ZoneWall" or name == "ZoneGatePrompt") and not refreshQueued then
		refreshQueued = true
		task.defer(function()
			refreshQueued = false
			refreshGates()
		end)
	end
end);

LandState.Changed:Connect(refreshGates)

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local function onProfile(newProfile)
	profile = newProfile
	refresh()
	refreshGates()
end
ClientState.Changed:Connect(onProfile)
if ClientState.Get() then
	onProfile(ClientState.Get())
end

local notifyToken = 0;
(remotes:WaitForChild("Notify") :: RemoteEvent).OnClientEvent:Connect(function(message: string)
	notifyToken += 1
	local token = notifyToken
	notifyLabel.Text = message
	task.delay(2.5, function()
		if notifyToken == token then
			notifyLabel.Text = ""
		end
	end)
end);

(remotes:WaitForChild("QueueUpdated") :: RemoteEvent).OnClientEvent:Connect(function(names: { string }, maxSize: number, countdown: number?)
	if #names == 0 then
		notifyLabel.Text = ""
	else
		notifyLabel.Text = ("Party %d/%d: %s%s"):format(
			#names,
			maxSize,
			table.concat(names, ", "),
			countdown and (" — starting in " .. countdown .. "s") or ""
		)
	end
end)

refresh()
