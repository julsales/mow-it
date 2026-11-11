--!strict
-- GRAYBOX ONLY — the placeholder lobby (queue pad, showcase lots, market),
-- built from the shared map props when the place has no Lobby yet. The
-- land itself is built by MapService. Replace in Studio when real art lands.

local Workspace = game:GetService("Workspace")

local Props = require(script.Parent.Map.Props)

local GrayboxService = {}

local GROUND_TOP = Props.GroundTop
local COLORS = Props.Colors
-- Far past the land's outer forest, so the two never overlap in Studio's
-- combined mode.
local LOBBY_CENTER = Vector3.new(0, 0, 640)

local make, box, label, model, gable, sign, tree = Props.make, Props.box, Props.label, Props.model, Props.gable, Props.sign, Props.tree

function GrayboxService.BuildLobbyIfMissing()
	if Workspace:FindFirstChild("Lobby") then
		return
	end
	Props.BuildAmbience()
	-- In Studio both places are built in one world. The lobby then sits
	-- across the street in front of the land; outside Studio it's alone.
	local landExists = Workspace:FindFirstChild("Zones") ~= nil

	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	local c = LOBBY_CENTER
	local ground = CFrame.new(c.X, GROUND_TOP, c.Z)

	make("Plaza", lobby, {
		Size = Vector3.new(160, 2, 90),
		CFrame = CFrame.new(c.X, GROUND_TOP - 1, c.Z),
		Color = COLORS.Path,
		Material = Enum.Material.Pavement,
	})
	-- The street, along the land side of the plaza.
	box("Street", lobby, ground, Vector3.new(160, 0.2, 14), 0, -36, COLORS.Road, Enum.Material.Asphalt)
	box("StreetLine", lobby, ground, Vector3.new(150, 0.05, 0.5), 0, -36, COLORS.RoadLine, nil, 0.2)

	local pad = box("JoinPad", lobby, ground, Vector3.new(14, 0.6, 14), 0, -12, Color3.fromRGB(70, 200, 120), Enum.Material.Neon)
	label(pad, Enum.NormalId.Top, "PLAY\n(party up to 4)", Color3.fromRGB(10, 60, 30))

	-- Showcase lots (spec: lobby-showcase-and-party). Empty placeholders.
	for i, x in { -60, -36, 36, 60 } do
		local lot = box("ShowcaseLot" .. i, lobby, ground, Vector3.new(18, 0.3, 18), x, 4, Color3.fromRGB(150, 196, 110), Enum.Material.Grass)
		label(lot, Enum.NormalId.Top, "SHOWCASE\n(soon)", Color3.fromRGB(40, 70, 30))
	end

	local market = model("CrewMarket", lobby)
	local marketFrame = ground * CFrame.new(0, 0, 30) * CFrame.Angles(0, math.rad(180), 0)
	gable(market, marketFrame, 0, 0, 30, 10, 14, Color3.fromRGB(250, 236, 200), Color3.fromRGB(70, 150, 120), Vector2.new(6, 8))
	sign(market, marketFrame, -12, 12, "CREW MARKET\n(soon)", Color3.fromRGB(70, 150, 120))

	for _, x in { -76, 76 } do
		for _, z in { -24, 34 } do
			tree(lobby, ground, x, z, 0.9)
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.Position = Vector3.new(c.X, GROUND_TOP + 0.2, c.Z + 10)
	spawn.Color = COLORS.White
	spawn.Material = Enum.Material.Concrete
	spawn.Duration = 0
	-- Studio combined mode: always start on the land (that's what Play is
	-- for most of the time). To playtest the queue pad in Studio, enable
	-- LobbySpawn (or disable GameSpawn) in the Explorer while playing.
	spawn.Enabled = not landExists
	spawn.Parent = lobby

	lobby.Parent = Workspace
end

return GrayboxService
