--!strict
-- GRAYBOX ONLY — delete/replace as the real maps are built in Studio.
-- If the map contract instances are missing, this creates plain labeled
-- blocks so a brand-new place is playable end-to-end (lobby pad, one field
-- per zone in a row, sell pads, zone gates) before any builder work.
-- Nothing here is final art; everything is named so builders can find and
-- replace it piece by piece (docs/DEVELOPMENT_PLAN.md, Maps phase).

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)

local GrayboxService = {}

local function block(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

local function label(parent: BasePart, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.Parent = parent
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.TextScaled = true
	textLabel.Text = text
	textLabel.Parent = gui
end

function GrayboxService.BuildLobbyIfMissing()
	if Workspace:FindFirstChild("Lobby") then
		return
	end
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = Workspace
	block("Floor", Vector3.new(60, 1, 60), Vector3.new(0, -0.5, 0), Color3.fromRGB(180, 180, 180), lobby)
	local pad = block("JoinPad", Vector3.new(12, 1, 12), Vector3.new(0, 0.5, 0), Color3.fromRGB(70, 200, 120), lobby)
	label(pad, "PLAY (up to 4)")
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 0.5, 20)
	spawn.Parent = lobby
end

function GrayboxService.BuildZonesIfMissing()
	if Workspace:FindFirstChild("Zones") then
		return
	end
	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = Workspace

	for i, zone in Zones.List do
		local originX = (i - 1) * 90
		local folder = Instance.new("Folder")
		folder.Name = zone.Id
		folder.Parent = zonesFolder

		local area = block(
			"GrassArea",
			Vector3.new(70, 1, 70),
			Vector3.new(originX, -0.5, 0),
			zone.ThemeColor,
			folder
		)
		label(area, zone.DisplayName)

		local sellPad = block(
			"SellPad",
			Vector3.new(10, 1, 10),
			Vector3.new(originX, 0.5, 42),
			Color3.fromRGB(255, 205, 60),
			folder
		)
		label(sellPad, "SELL")

		if i > 1 then
			local gate = block(
				"ZoneGate",
				Vector3.new(2, 12, 30),
				Vector3.new(originX - 45, 6, 0),
				Color3.fromRGB(90, 90, 90),
				folder
			)
			label(gate, "LOCKED: " .. zone.DisplayName)
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "GameSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 0.5, 45)
	spawn.Parent = Workspace
end

return GrayboxService
