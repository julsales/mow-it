--!strict
-- GRAYBOX ONLY — the placeholder lobby (queue pad, showcase lots, market),
-- built from the shared map props when the place has no Lobby yet. The
-- land itself is built by MapService. Replace in Studio when real art lands.

local Workspace = game:GetService("Workspace")

local Props = require(script.Parent.Map.Props)
local Showcase = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Showcase)

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

	-- The two ways into play (LobbyService): PLAY = alone on your own land,
	-- PARTY = up to 4 on the land of whoever stepped on first.
	local function pad(name: string, x: number, color: Color3, title: string, subtitle: string)
		box(name, lobby, ground, Vector3.new(13, 0.5, 13), x, -14, color, Enum.Material.Neon)
		box(name .. "Rim", lobby, ground, Vector3.new(14.5, 0.3, 14.5), x, -14, COLORS.White)
		-- An arch over the pad carries its name, readable from the spawn.
		local arch = model(name .. "Arch", lobby)
		for _, dx in { -7, 7 } do
			box("Post", arch, ground, Vector3.new(0.9, 11, 0.9), x + dx, -20.5, COLORS.DarkWood, Enum.Material.Wood)
		end
		local board = box("Board", arch, ground, Vector3.new(15, 3.6, 0.6), x, -20.5, COLORS.Cream, Enum.Material.WoodPlanks, 7.6)
		label(board, Enum.NormalId.Back, title, color:Lerp(Color3.new(0, 0, 0), 0.55))
		local small = box("Subtitle", arch, ground, Vector3.new(12, 1.5, 0.5), x, -20.5, COLORS.White, Enum.Material.WoodPlanks, 5.9)
		label(small, Enum.NormalId.Back, subtitle)
	end
	pad("PlayPad", -13, Color3.fromRGB(70, 200, 120), "PLAY", "Your land, solo")
	pad("PartyPad", 13, Color3.fromRGB(90, 160, 240), "PARTY", "Up to 4 on the host's land")

	-- Showcase lots (spec: lobby-showcase-and-party): filled by
	-- Lobby/Showcase with a snapshot of each visitor's progress.
	for _, x in { -66, -40, 40, 66 } do
		make("ShowcaseLot", lobby, {
			Size = Vector3.new(Showcase.LotSize, 0.3, Showcase.LotSize),
			-- Front (-Z of the part) faces the pads and the street.
			CFrame = CFrame.new(c.X + x, GROUND_TOP + 0.15, c.Z + 14),
			Color = Color3.fromRGB(150, 196, 110),
			Material = Enum.Material.Grass,
		})
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
	spawn.Position = Vector3.new(c.X, GROUND_TOP + 0.2, c.Z + 4)
	spawn.Color = COLORS.White
	spawn.Material = Enum.Material.Concrete
	spawn.Duration = 0
	-- Studio combined mode: always start on the land (that's what Play is
	-- for most of the time). To playtest the lobby pads in Studio, enable
	-- LobbySpawn (or disable GameSpawn) in the Explorer while playing.
	spawn.Enabled = not landExists
	spawn.Parent = lobby

	lobby.Parent = Workspace
end

return GrayboxService
