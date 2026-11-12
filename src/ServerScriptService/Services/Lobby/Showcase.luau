--!strict
-- Showcase lots in the lobby (spec: lobby-showcase-and-party, design D3).
-- Each player in the lobby gets a free lot showing a SNAPSHOT of their
-- progress: a house that grows with their land, their best tool, and a
-- sign with their company name and headline stats. A lot is display only;
-- it holds no economy and nothing on it can be interacted with.
--
-- Lots are contract parts named "ShowcaseLot" under Workspace/Lobby (flat
-- pads; their top is the ground, their front is the part's -Z side). The
-- builder fills `<lot>/Display` and never touches anything else, so lots
-- can be moved, resized and dressed by hand in Studio.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Showcase)
local Tools = require(Shared.Config.Tools)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Format)
local ToolModels = require(Shared.ToolModels)

local Services = script.Parent.Parent
local ProfileService = require(Services.ProfileService)
local Props = require(Services.Map.Props)

local Showcase = {}

local COLORS = Props.Colors
local RAD180 = math.rad(180)

-- What a lot shows. Plain values only: the lot never reads the profile again.
export type Snapshot = {
	Name: string,
	Level: number,
	Expansions: number,
	LifetimeGrass: number,
	BestToolId: string,
}

function Showcase.Snapshot(player: Player, profile: ProfileService.Profile): Snapshot
	local best = Tools.List[1].Id
	for _, def in Tools.List do -- the list is the ladder, weakest first
		if profile.OwnedToolIds[def.Id] then
			best = def.Id
		end
	end
	return {
		Name = player.DisplayName,
		Level = profile.Level,
		Expansions = Zones.HighestUnlockedIndex(profile.UnlockedZoneIds),
		LifetimeGrass = profile.LifetimeGrass,
		BestToolId = best,
	}
end

-- Two snapshots that would build the same lot have the same key (the
-- grass counter is rounded the way the sign prints it).
local function keyOf(s: Snapshot): string
	return table.concat({ s.Name, tostring(s.Level), tostring(s.Expansions), Format.Number(s.LifetimeGrass), s.BestToolId }, "|")
end

-- Building blocks ---------------------------------------------------------------
-- All in the lot's frame `cf`: origin on the lot's surface, +Z = front.

local function fenceLine(parent: Instance, cf: CFrame, from: Vector2, to: Vector2)
	local delta = to - from
	local length = delta.Magnitude
	local posts = math.max(2, math.round(length / 3.6) + 1)
	for i = 0, posts - 1 do
		local p = from + delta * (i / (posts - 1))
		Props.box("Post", parent, cf, Vector3.new(0.5, 2.6, 0.5), p.X, p.Y, COLORS.Fence)
	end
	local mid = (from + to) / 2
	local facing = math.atan2(delta.X, delta.Y)
	for _, lift in { 1.0, 1.9 } do
		Props.make("Rail", parent, {
			Size = Vector3.new(0.25, 0.4, length),
			CFrame = Props.at(cf, mid.X, lift + 0.2, mid.Y) * CFrame.Angles(0, facing, 0),
			Color = COLORS.Fence,
		})
	end
end

-- Picket fence around the lot, open in the middle of the front.
local function fence(parent: Instance, cf: CFrame, size: number)
	local m = Props.model("Fence", parent)
	local h = size / 2 - 0.4
	local gap = 3
	fenceLine(m, cf, Vector2.new(-h, -h), Vector2.new(h, -h)) -- back
	fenceLine(m, cf, Vector2.new(-h, -h), Vector2.new(-h, h))
	fenceLine(m, cf, Vector2.new(h, -h), Vector2.new(h, h))
	fenceLine(m, cf, Vector2.new(-h, h), Vector2.new(-gap, h))
	fenceLine(m, cf, Vector2.new(gap, h), Vector2.new(h, h))
end

-- Wooden sign by the entrance: a title board and a smaller one under it.
local function signPost(parent: Instance, cf: CFrame, x: number, z: number, title: string, subtitle: string?, accent: Color3)
	local m = Props.model("Sign", parent)
	for _, dx in { -3.1, 3.1 } do
		Props.box("Post", m, cf, Vector3.new(0.5, 5.6, 0.5), x + dx, z - 0.1, COLORS.DarkWood, Enum.Material.Wood)
	end
	local top = Props.box("Title", m, cf, Vector3.new(7.2, 1.9, 0.4), x, z + 0.2, COLORS.Cream, Enum.Material.WoodPlanks, 3.9)
	Props.label(top, Enum.NormalId.Back, title, COLORS.DarkWood)
	Props.box("Stripe", m, cf, Vector3.new(7.2, 0.3, 0.5), x, z + 0.2, accent, nil, 5.8)
	if subtitle then
		local bottom = Props.box("Stats", m, cf, Vector3.new(6.6, 1.4, 0.35), x, z + 0.2, COLORS.White, Enum.Material.WoodPlanks, 2.3)
		Props.label(bottom, Enum.NormalId.Back, subtitle, COLORS.Text)
	end
end

-- The house for this many expansions, scaled to fit the lot, on the ground.
local function house(parent: Instance, cf: CFrame, expansions: number, z: number)
	local kinds = Config.HouseByExpansions
	local kind = Props.Kinds[kinds[math.clamp(expansions, 1, #kinds)]]
	local m = Props.model("House", parent)
	m.WorldPivot = CFrame.identity -- scale and place from the ground origin
	kind.Build(m, CFrame.identity)
	local _, size = m:GetBoundingBox()
	m:ScaleTo(Config.HouseFit / math.max(size.X, size.Z))
	m:PivotTo(Props.at(cf, 0, 0, z))
end

-- The best tool: mowers park on the grass, hand tools sit on a stand.
local function bestTool(parent: Instance, cf: CFrame, toolId: string, x: number, z: number)
	local model = ToolModels.BuildDisplay(toolId)
	model.Name = "BestTool"
	if model:GetAttribute("Ground") == true then
		local _, footprint = model:GetBoundingBox()
		-- Built with the player at the origin and the mower ahead (-Z):
		-- turn it to face the front and center the mower itself on the spot.
		model:PivotTo(Props.at(cf, x, 0, z) * CFrame.Angles(0, RAD180 + math.rad(25), 0) * CFrame.new(0, 0, footprint.Z / 2))
	else
		local stand = Props.model("Stand", parent)
		Props.box("Base", stand, cf, Vector3.new(2.6, 0.5, 2.6), x, z, COLORS.DarkWood, Enum.Material.Wood)
		Props.box("Block", stand, cf, Vector3.new(2, 1.5, 2), x, z, COLORS.Wood, Enum.Material.WoodPlanks, 0.5)
		local _, raw = model:GetBoundingBox()
		model:ScaleTo(model:GetScale() * Config.HandToolFit / math.max(raw.X, raw.Y, raw.Z))
		-- Lay it flat on the block, turned a little, centered by its bounds.
		local top = Props.at(cf, x, 2, z)
		model:PivotTo(top * CFrame.Angles(0, math.rad(35), 0))
		local bounds, size = model:GetBoundingBox()
		model:PivotTo(model:GetPivot() + (top.Position + Vector3.new(0, size.Y / 2, 0) - bounds.Position))
	end
	model.Parent = parent
end

-- Lots ----------------------------------------------------------------------------

local function frameOf(lot: BasePart): CFrame
	-- Top of the pad, +Z of the frame = the lot's front (-Z of the part).
	return lot.CFrame * CFrame.new(0, lot.Size.Y / 2, 0) * CFrame.Angles(0, RAD180, 0)
end

local function clear(lot: BasePart): Model
	local old = lot:FindFirstChild("Display")
	if old then
		old:Destroy()
	end
	return Props.model("Display", lot)
end

function Showcase.BuildVacant(lot: BasePart)
	local display = clear(lot)
	local cf = frameOf(lot)
	local size = math.min(lot.Size.X, lot.Size.Z)
	fence(display, cf, size)
	signPost(display, cf, 0, size / 2 - 3, Config.VacantText, nil, COLORS.Curb)
end

function Showcase.Build(lot: BasePart, snapshot: Snapshot)
	local display = clear(lot)
	local cf = frameOf(lot)
	local size = math.min(lot.Size.X, lot.Size.Z)
	local zone = Zones.List[math.clamp(snapshot.Expansions, 1, #Zones.List)]
	fence(display, cf, size)
	house(display, cf, snapshot.Expansions, -size / 2 + Config.HouseFit / 2 + 1.5)
	local houseFront = -size / 2 + Config.HouseFit + 1.5
	-- Garden path from the gate to the door, and a bush in each front corner.
	local pathLength = size / 2 - houseFront
	Props.make("Path", display, {
		Size = Vector3.new(2.6, 0.12, pathLength),
		CFrame = Props.at(cf, 0, 0.06, houseFront + pathLength / 2),
		Color = COLORS.Sand,
		Material = Enum.Material.Sand,
		Solid = false,
	})
	for _, dx in { -size / 2 + 2, size / 2 - 2 } do
		Props.ball("Bush", display, cf, 2.4, dx, 0.9, size / 2 - 2, COLORS.Leaves, Enum.Material.Grass)
		Props.ball("Bush", display, cf, 1.6, dx - 0.9 * math.sign(dx), 0.6, size / 2 - 3.2, COLORS.DarkLeaves, Enum.Material.Grass)
	end
	bestTool(display, cf, snapshot.BestToolId, size / 2 - 5.5, houseFront + 4)
	local stats = ("Level %d  ·  %d/%d lands  ·  %s cut"):format(snapshot.Level, snapshot.Expansions, #Zones.List, Format.Number(snapshot.LifetimeGrass))
	signPost(display, cf, -size / 2 + 5, size / 2 - 3.4, snapshot.Name .. Config.CompanySuffix, stats, zone.ThemeColor)
end

-- Assignment -----------------------------------------------------------------------

local lots: { BasePart } = {}
local ownerOf: { [BasePart]: Player } = {}
local lotOf: { [Player]: BasePart } = {}
local shownKey: { [Player]: string } = {}

local function refresh(player: Player)
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	local lot = lotOf[player]
	if not lot then
		for _, candidate in lots do
			if not ownerOf[candidate] then
				lot = candidate
				ownerOf[candidate] = player
				lotOf[player] = candidate
				break
			end
		end
	end
	if not lot then
		return -- lobby fuller than its lots: no showcase this visit
	end
	local snapshot = Showcase.Snapshot(player, profile)
	local key = keyOf(snapshot)
	if shownKey[player] ~= key then
		shownKey[player] = key
		Showcase.Build(lot, snapshot)
	end
end

local function release(player: Player)
	local lot = lotOf[player]
	lotOf[player] = nil
	shownKey[player] = nil
	if lot then
		ownerOf[lot] = nil
		Showcase.BuildVacant(lot)
	end
end

function Showcase.Init(lobby: Instance)
	for _, d in lobby:GetDescendants() do
		if d.Name == "ShowcaseLot" and d:IsA("BasePart") then
			table.insert(lots, d)
		end
	end
	-- Fill from the same end every time (left to right as built).
	table.sort(lots, function(a, b)
		return a.Position.X < b.Position.X
	end)
	for _, lot in lots do
		Showcase.BuildVacant(lot)
	end
	ProfileService.OnChanged(function(player)
		task.spawn(refresh, player)
	end)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		task.spawn(refresh, player)
	end
end

return Showcase
