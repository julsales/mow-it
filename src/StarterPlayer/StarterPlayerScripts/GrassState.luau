--!strict
-- The local player's own lawn, painted on this client only.
--
-- The islands are shared but every player mows their own grass
-- (GrassService on the server owns it as data). The server tells this
-- client which of ITS cells were mowed and when they regrow (GrassCut) and
-- where its rare patches are (GrassPatch); here that becomes:
--   * terrain: a mowed cell turns from tall Grass into short striped lawn
--     in this client's copy of the terrain, and back when it regrows.
--     Terrain edits made on a client are never sent to anybody else;
--   * patch markers in Workspace/RareGrass (attributes GrassType + Look),
--     which GrassTufts draws blades for; lucky/golden ones sparkle so they
--     can be chased from far away.
-- Nothing is asked of the server per cell: one message per swing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GrassTypes = require(Shared.Config.GrassTypes)
local Zones = require(Shared.Config.Zones)
local LawnCells = require(Shared.LawnCells)

local GrassState = {}

local CELL = LawnCells.Size
local terrain = Workspace.Terrain
local markers: Folder
local markerAt: { [string]: BasePart } = {}
local regrowAt: { [string]: number } = {} -- cut cells -> os.clock() they stand again
local started = false

local function keyOf(center: Vector3): (string, number)
	local ix, iz = LawnCells.Index(center)
	return LawnCells.Key(ix, iz), ix
end

local function dropMarker(key: string)
	local marker = markerAt[key]
	if marker then
		markerAt[key] = nil
		marker:Destroy()
	end
end

local function addMarker(key: string, center: Vector3, typeId: string, lookId: string)
	dropMarker(key)
	local marker = Instance.new("Part")
	marker.Name = typeId
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.CastShadow = false
	marker.Transparency = 1
	marker.Size = Vector3.new(CELL, 0.2, CELL)
	marker.Position = center + Vector3.new(0, 0.6, 0)
	-- Sparkles: lucky/golden shine in their own color; next-area patches
	-- glint softly in that area's theme color.
	local look = GrassTypes.Looks[lookId]
	local glint = if look and look.Sparkle then look.Sparkle elseif typeId == "next" and Zones.ById[lookId] then Zones.ById[lookId].ThemeColor else nil
	if glint then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(glint)
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new(0.9, 0)
		sparkle.Lifetime = NumberRange.new(0.9, 1.6)
		sparkle.Rate = if look and look.Sparkle then 4 else 1.5
		sparkle.Speed = NumberRange.new(1.5, 3.5)
		sparkle.SpreadAngle = Vector2.new(25, 25)
		sparkle.EmissionDirection = Enum.NormalId.Top
		sparkle.Parent = marker
	end
	marker:SetAttribute("GrassType", typeId)
	marker:SetAttribute("Look", lookId)
	marker.Parent = markers
	markerAt[key] = marker
end

local function onCut(centers: { Vector3 }, delays: { number })
	local now = os.clock()
	for i, center in centers do
		local key, ix = keyOf(center)
		local due = now + (delays[i] or 0)
		regrowAt[key] = due
		dropMarker(key) -- a mowed patch cell is gone; the server sends the next one
		local region = LawnCells.Region(center)
		local mowed = LawnCells.Mowed(ix)
		terrain:ReplaceMaterial(region, CELL, LawnCells.Tall, mowed)
		task.delay(delays[i] or 0, function()
			if regrowAt[key] == due then
				regrowAt[key] = nil
				terrain:ReplaceMaterial(region, CELL, mowed, LawnCells.Tall)
			end
		end)
	end
end

local function onPatch(centers: { Vector3 }, typeIds: { string }, looks: { string })
	for i, center in centers do
		local key = keyOf(center)
		if typeIds[i] == "" then
			dropMarker(key)
		else
			addMarker(key, center, typeIds[i], looks[i])
		end
	end
end

-- Creates Workspace/RareGrass, listens to the server and asks for this
-- player's lawn. Call once, before GrassTufts.Start (it reads the folder).
function GrassState.Start()
	if started then
		return
	end
	started = true
	markers = Instance.new("Folder")
	markers.Name = "RareGrass"
	markers.Parent = Workspace
	local remotes = ReplicatedStorage:WaitForChild("Remotes");
	(remotes:WaitForChild("GrassCut") :: RemoteEvent).OnClientEvent:Connect(onCut);
	(remotes:WaitForChild("GrassPatch") :: RemoteEvent).OnClientEvent:Connect(onPatch);
	(remotes:WaitForChild("GrassSync") :: RemoteEvent):FireServer()
end

return GrassState
