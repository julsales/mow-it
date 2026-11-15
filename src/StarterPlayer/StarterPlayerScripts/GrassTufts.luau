--!strict
-- Grass blades drawn by each client on top of the terrain lawns, so every
-- area's grass looks different (color, height, blade shape; GrassTypes
-- `Looks`) and lucky/golden/next-area patches stand out.
--
-- * Where: lawn cells from the GrassArea contract parts (Shared/LawnCells).
-- * Which look: the cell's area, unless it has a patch marker
--   (Workspace/RareGrass, attribute `Look`; GrassState puts them there for
--   the local player's own patches).
-- * Standing or mowed: read from this client's terrain (tall Grass
--   material = standing), which GrassState paints as the local player
--   mows: every player sees their own lawn.
-- * Snipped blades: the first hand tools cut single blades (Config/Tools
--   `Blades`). A cell being cut that way (GrassState.Snipped) is drawn as
--   GrassTypes.SnipBlades single blades on short ground, minus the ones
--   already gone, so it thins out blade by blade until it is mowed.
--
-- Only chunks near the camera are drawn (RADIUS); blades are anchored,
-- non-colliding parts built once per chunk and hidden while mowed.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GrassTypes = require(Shared.Config.GrassTypes)
local LawnCells = require(Shared.LawnCells)
local GrassState = require(script.Parent:WaitForChild("GrassState"))

local GrassTufts = {}

local CELL = LawnCells.Size
local CHUNK_CELLS = 8
local CHUNK = CELL * CHUNK_CELLS
local RADIUS = 76 -- studs from the camera focus that get blades
local REFRESH = 0.3 -- seconds between terrain reads / chunk updates
local BUILDS_PER_TICK = 3
local TALL = Enum.Material.Grass

type Cell = LawnCells.Cell
type Chunk = {
	Folder: Folder,
	Parts: { [string]: { BasePart } }, -- cell key -> the parts of its blades
	BladeOf: { [string]: { number } }, -- cell key -> which blade (1..n) each part belongs to
	Thin: { [string]: boolean }, -- cell key -> built as single snippable blades
	Shown: { [string]: boolean },
	Looks: { [string]: string },
}

local cellsByChunk: { [string]: { Cell } } = {}
local cellByKey: { [string]: Cell } = {}
local lookOverride: { [string]: string } = {} -- cell key -> look (patches)
local snips: { [string]: { Vector3 } } = {} -- cell key -> where its blades were just snipped (TakeSnip)
local chunks: { [string]: Chunk } = {}
local folder: Folder
local terrain = Workspace.Terrain

local function chunkKey(ix: number, iz: number): (string, number, number)
	local cx, cz = math.floor(ix / CHUNK_CELLS), math.floor(iz / CHUNK_CELLS)
	return cx .. "," .. cz, cx, cz
end

local function lookOf(cell: Cell): (string, GrassTypes.Look?)
	local id = lookOverride[LawnCells.Key(cell.Ix, cell.Iz)] or cell.ZoneId
	return id, GrassTypes.Looks[id]
end

-- One blade-ish part.
local function part(parent: Instance, className: string, size: Vector3, cf: CFrame, color: Color3, glow: boolean?): BasePart
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- Builds the blades of one cell (deterministic per cell, so every client
-- sees the same lawn).
local function buildCell(parent: Instance, cell: Cell, look: GrassTypes.Look): ({ BasePart }, { number })
	local rng = Random.new(cell.Ix * 73856093 + cell.Iz * 19349663)
	local parts: { BasePart } = {}
	local bladeOf: { number } = {}
	local base = cell.Center
	local tip = look.Tip or look.Color
	for i = 1, look.Blades do
		local offset = Vector3.new((rng:NextNumber() - 0.5) * (CELL - 0.6), 0, (rng:NextNumber() - 0.5) * (CELL - 0.6))
		local yaw = rng:NextNumber() * math.pi * 2
		local h = look.Height * (0.75 + rng:NextNumber() * 0.45)
		local w = look.Width * (0.8 + rng:NextNumber() * 0.4)
		local color = look.Color:Lerp(tip, rng:NextNumber() * 0.35)
		local ground = CFrame.new(base + offset) * CFrame.Angles(0, yaw, 0)
		local shape = look.Shape
		if shape == "Blade" or shape == "Flower" or shape == "Tuft" then
			local lean = if shape == "Tuft" then 0.25 + rng:NextNumber() * 0.3 else (rng:NextNumber() - 0.5) * 0.3
			local blade = ground * CFrame.Angles(lean, 0, 0) * CFrame.new(0, h / 2, 0)
			table.insert(parts, part(parent, "WedgePart", Vector3.new(0.1, h, w), blade, color, look.Glow))
			if shape == "Tuft" then
				-- A second blade crossing the first: tufts look bushy.
				local cross = ground * CFrame.Angles(0, math.pi / 2, -lean) * CFrame.new(0, h * 0.42, 0)
				table.insert(parts, part(parent, "WedgePart", Vector3.new(0.1, h * 0.85, w * 0.8), cross, look.Color:Lerp(tip, 0.5), look.Glow))
			elseif shape == "Flower" and (i == 1 or (i == 2 and rng:NextNumber() < 0.4)) then
				local flower = part(parent, "Part", Vector3.one * 0.5, blade * CFrame.new(0, h * 0.45, 0), if i == 1 then tip else Color3.fromRGB(250, 250, 245))
				flower.Shape = Enum.PartType.Ball
				table.insert(parts, flower)
			end
		elseif shape == "Stalk" then
			local lean = (rng:NextNumber() - 0.5) * 0.25
			local stalk = ground * CFrame.Angles(lean, 0, 0)
			table.insert(parts, part(parent, "Part", Vector3.new(w * 0.5, h, w * 0.5), stalk * CFrame.new(0, h / 2, 0), color, look.Glow))
			-- The ear: a slim head leaning a little, like wheat.
			local ear = stalk * CFrame.new(0, h, 0) * CFrame.Angles(lean + 0.2, 0, 0) * CFrame.new(0, h * 0.14, 0)
			table.insert(parts, part(parent, "Part", Vector3.new(w * 0.9, h * 0.3, w * 0.9), ear, tip, look.Glow))
		elseif shape == "Clover" then
			for leaf = 1, 3 do
				local a = leaf * math.pi * 2 / 3
				local leafCf = ground * CFrame.Angles(0, a, 0) * CFrame.new(0, h, -w * 0.32) * CFrame.Angles(0, 0, math.pi / 2)
				local leafPart = part(parent, "Part", Vector3.new(0.12, w * 0.7, w * 0.7), leafCf, look.Color, look.Glow)
				leafPart.Shape = Enum.PartType.Cylinder
				table.insert(parts, leafPart)
			end
			table.insert(parts, part(parent, "Part", Vector3.new(0.12, h, 0.12), ground * CFrame.new(0, h / 2, 0), look.Color:Lerp(Color3.new(0, 0.3, 0), 0.3)))
		end
		for index = #bladeOf + 1, #parts do
			bladeOf[index] = i
		end
	end
	return parts, bladeOf
end

-- Shows the cell's blades that are still there: none while mowed, all but
-- the snipped ones (the first blades) while standing.
local function paint(chunk: Chunk, k: string)
	local shown = chunk.Shown[k] ~= false
	local gone = GrassState.Snipped(k) or 0
	local bladeOf = chunk.BladeOf[k]
	for index, p in chunk.Parts[k] or {} do
		p.Transparency = if shown and bladeOf[index] > gone then 0 else 1
	end
end

local function setShown(chunk: Chunk, k: string, shown: boolean)
	if chunk.Shown[k] == shown then
		return
	end
	chunk.Shown[k] = shown
	paint(chunk, k)
end

local function rebuildCell(chunk: Chunk, cell: Cell)
	local k = LawnCells.Key(cell.Ix, cell.Iz)
	for _, p in chunk.Parts[k] or {} do
		p:Destroy()
	end
	local id, look = lookOf(cell)
	chunk.Looks[k] = id
	local thin = GrassState.Snipped(k) ~= nil
	chunk.Thin[k] = thin
	if look and thin then
		-- Being cut blade by blade: the same grass as single blades.
		local single = table.clone(look)
		single.Blades = GrassTypes.SnipBlades
		chunk.Parts[k], chunk.BladeOf[k] = buildCell(chunk.Folder, cell, single)
	elseif look then
		chunk.Parts[k], chunk.BladeOf[k] = buildCell(chunk.Folder, cell, look)
	else
		chunk.Parts[k], chunk.BladeOf[k] = {}, {}
	end
	local shown = chunk.Shown[k]
	chunk.Shown[k] = nil
	setShown(chunk, k, shown ~= false)
end

local function loadChunk(key: string)
	local chunk: Chunk = { Folder = Instance.new("Folder"), Parts = {}, BladeOf = {}, Thin = {}, Shown = {}, Looks = {} }
	chunk.Folder.Name = key
	for _, cell in cellsByChunk[key] do
		rebuildCell(chunk, cell)
	end
	chunk.Folder.Parent = folder
	chunks[key] = chunk
end

-- Standing/mowed from the terrain: one ReadVoxels per chunk.
local function readChunk(key: string, chunk: Chunk)
	local cells = cellsByChunk[key]
	local first = cells[1]
	local cx, cz = math.floor(first.Ix / CHUNK_CELLS), math.floor(first.Iz / CHUNK_CELLS)
	local bottom = math.floor((first.Center.Y - 2.01) / CELL) * CELL
	local region = Region3.new(Vector3.new(cx * CHUNK, bottom, cz * CHUNK), Vector3.new(cx * CHUNK + CHUNK, bottom + CELL, cz * CHUNK + CHUNK))
	local ok, materials = pcall(function()
		return (terrain:ReadVoxels(region, CELL))
	end)
	if not ok then
		return
	end
	for _, cell in cells do
		local column = materials[cell.Ix - cx * CHUNK_CELLS + 1]
		local material = column and column[1] and column[1][cell.Iz - cz * CHUNK_CELLS + 1]
		local k = LawnCells.Key(cell.Ix, cell.Iz)
		local snipped = GrassState.Snipped(k) ~= nil
		if material == TALL and chunk.Thin[k] and not snipped then
			rebuildCell(chunk, cell) -- regrown whole: thick grass again
		end
		-- A cell being snipped stands on short ground already (GrassState).
		setShown(chunk, k, material == TALL or snipped)
	end
end

local function addCells(list: { Cell })
	for _, cell in list do
		local k = LawnCells.Key(cell.Ix, cell.Iz)
		if not cellByKey[k] then
			cellByKey[k] = cell
			local ck = chunkKey(cell.Ix, cell.Iz)
			cellsByChunk[ck] = cellsByChunk[ck] or {}
			table.insert(cellsByChunk[ck], cell)
			local loaded = chunks[ck]
			if loaded then
				rebuildCell(loaded, cell)
			end
		end
	end
end

local function onMarker(marker: Instance, added: boolean)
	if not marker:IsA("BasePart") then
		return
	end
	local ix, iz = LawnCells.Index(marker.Position)
	local k = LawnCells.Key(ix, iz)
	local look = marker:GetAttribute("Look")
	if added and type(look) == "string" then
		lookOverride[k] = look
	elseif not added then
		lookOverride[k] = nil
	end
	local cell = cellByKey[k]
	local chunk = cell and chunks[(chunkKey(ix, iz))]
	if cell and chunk and chunk.Looks[k] ~= (lookOf(cell)) then
		rebuildCell(chunk, cell)
	end
end

-- The color of the grass at a point (for clippings), or nil off the lawns.
function GrassTufts.ColorAt(point: Vector3): Color3?
	local ix, iz = LawnCells.Index(point)
	local cell = cellByKey[LawnCells.Key(ix, iz)]
	if not cell then
		return nil
	end
	local _, look = lookOf(cell)
	return look and look.Color
end

-- A cell lost a blade (`cut` so far) or was mowed (nil): redraw it now and
-- remember where the blade stood, for the pickup.
local function onSnip(center: Vector3, cut: number?)
	local ix, iz = LawnCells.Index(center)
	local k = LawnCells.Key(ix, iz)
	local cell = cellByKey[k]
	local chunk = chunks[(chunkKey(ix, iz))]
	if not cell or not chunk or not chunk.Parts[k] then
		return
	end
	if cut and not chunk.Thin[k] then
		rebuildCell(chunk, cell)
	end
	-- The blade that just went: number `cut`, or the last one left.
	local at = chunk.Thin[k] and table.find(chunk.BladeOf[k], cut or GrassTypes.SnipBlades)
	if at then
		local position = chunk.Parts[k][at].Position
		local list = snips[k] or {}
		snips[k] = list
		table.insert(list, Vector3.new(position.X, center.Y, position.Z))
		if #list > GrassTypes.SnipBlades then
			table.remove(list, 1)
		end
	end
	if cut then
		paint(chunk, k)
	else
		setShown(chunk, k, false)
	end
end

-- Where the blade just snipped from the cell at `point` stood (once per
-- blade, oldest first), so the pickup can fly from that very blade; nil
-- when the cell was mowed whole.
function GrassTufts.TakeSnip(point: Vector3): Vector3?
	local ix, iz = LawnCells.Index(point)
	local list = snips[LawnCells.Key(ix, iz)]
	return list and table.remove(list, 1)
end

function GrassTufts.Start()
	folder = Instance.new("Folder")
	folder.Name = "GrassTufts (local)"
	folder.Parent = Workspace
	GrassState.OnSnip(onSnip)

	-- Lawns: everything already there, and parts that stream in later (on
	-- the islands and on the personal bases).
	task.spawn(function()
		Workspace:WaitForChild("Zones")
		local seen: { [string]: boolean } = {}
		local function fromPart(p: Instance)
			if p.Name == "GrassArea" and p:IsA("BasePart") then
				local zoneId = LawnCells.ZoneOf(p)
				if zoneId then
					local list = {}
					LawnCells.InPart(p, zoneId, seen, list)
					addCells(list)
				end
			end
		end
		for _, root in LawnCells.Roots() do
			for _, d in root:GetDescendants() do
				fromPart(d)
			end
			root.DescendantAdded:Connect(fromPart)
		end
	end)
	task.spawn(function()
		local markers = Workspace:WaitForChild("RareGrass")
		for _, m in markers:GetChildren() do
			onMarker(m, true)
		end
		markers.ChildAdded:Connect(function(m)
			-- Attributes replicate with the part; wait a frame to be safe.
			task.defer(onMarker, m, true)
		end)
		markers.ChildRemoved:Connect(function(m)
			onMarker(m, false)
		end)
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < REFRESH then
			return
		end
		elapsed = 0
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local focus = camera.Focus.Position
		-- Unload far chunks, read near ones, build a few missing ones.
		local reach = RADIUS + CHUNK
		for key, chunk in chunks do
			local cx, cz = string.match(key, "^(-?%d+),(-?%d+)$")
			local center = Vector3.new((tonumber(cx) :: number + 0.5) * CHUNK, focus.Y, (tonumber(cz) :: number + 0.5) * CHUNK)
			if (center - focus).Magnitude > reach then
				chunk.Folder:Destroy()
				chunks[key] = nil
			else
				readChunk(key, chunk)
			end
		end
		local built = 0
		local r = math.ceil(RADIUS / CHUNK)
		local fx, fz = math.floor(focus.X / CHUNK), math.floor(focus.Z / CHUNK)
		for dx = -r, r do
			for dz = -r, r do
				local key = (fx + dx) .. "," .. (fz + dz)
				local center = Vector3.new((fx + dx + 0.5) * CHUNK, focus.Y, (fz + dz + 0.5) * CHUNK)
				if not chunks[key] and cellsByChunk[key] and (center - focus).Magnitude <= RADIUS + CHUNK / 2 and built < BUILDS_PER_TICK then
					loadChunk(key)
					readChunk(key, chunks[key])
					built += 1
				end
			end
		end
	end)
end

return GrassTufts
