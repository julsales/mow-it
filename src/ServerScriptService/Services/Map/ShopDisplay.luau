--!strict
-- A physical tool shop: hand tools hang on a pegboard, mowers are parked
-- in front, each with a price tag and a "Buy" prompt. Reused by every
-- area's shop (MapService): give it a frame and a list of tool ids.
--
-- Server side builds the display and handles prompts through ShopService
-- (same validation as the Shop panel). The per-player text (price / Equip
-- / Equipped / locked) is painted by ShopDisplay.client.luau, since each
-- player owns different tools.
--
-- Frame: origin on the ground at the wall's center, +Z pointing out of
-- the wall toward the player, +X along the wall.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tools = require(Shared.Config.Tools)
local ToolModels = require(Shared.ToolModels)

local Props = require(script.Parent.Props)

local ShopDisplay = {}

export type Options = {
	BoardWidth: number?, -- pegboard width (studs)
	BoardHeight: number?,
	BoardLift: number?, -- height of the board's bottom edge
	BoardOffsetX: number?, -- board center along the wall
	ParkOffsetX: number?, -- where the mower row starts along the wall
	ParkDistance: number?, -- how far in front of the wall mowers park
	MaxParked: number?, -- mowers shown in front (the rest: Shop panel)
}

-- Prompts are wired at runtime, not when built, so shops baked into the
-- place in Edit mode work too: every ProximityPrompt named
-- "ShopItemPrompt" under a part with a ToolId attribute buys/equips it.
local buy: ((Player, string) -> ())? = nil
local wired: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function wire(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") or prompt.Name ~= "ShopItemPrompt" or wired[prompt] then
		return
	end
	wired[prompt] = true
	prompt.Triggered:Connect(function(player)
		local holder = prompt.Parent
		local toolId = holder and holder:GetAttribute("ToolId")
		if buy and typeof(toolId) == "string" then
			buy(player, toolId)
		end
	end)
end

function ShopDisplay.Init(handler: (Player, string) -> ())
	buy = handler
	for _, d in workspace:GetDescendants() do
		wire(d)
	end
	workspace.DescendantAdded:Connect(wire)
end

local function anchorAll(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			d:Destroy() -- anchored display, no welds needed
		end
	end
end

-- Corners of every part of `model`, in `frame` space: (min, max).
local function bounds(model: Model, frame: CFrame): (Vector3, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local half = d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local p = frame:PointToObjectSpace(d.CFrame * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
						lo, hi = lo:Min(p), hi:Max(p)
					end
				end
			end
		end
	end
	return lo, hi
end

-- Mounts a hand tool (built at the origin) flat on a board. `face`: the
-- board's front face, +Z out toward the player. The tool points down the
-- board, turned by `tilt` degrees, with its flat side against the board
-- and its top toward the player (never into the wall), scaled to fit a
-- `fitW` x `fitH` area centred at `center` (face space), standing just
-- off the face.
local function mount(model: Model, face: CFrame, center: Vector2, fitW: number, fitH: number, tilt: number)
	local _, size = model:GetBoundingBox()
	-- Model axes in face space: -Z (the tool's point) goes down; the
	-- thinner of X/Y faces the player, so we see the tool's wide side.
	local back = Vector3.new(0, 1, 0)
	local up = if size.X < size.Y then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
	local right = up:Cross(back)
	local turn = CFrame.Angles(0, 0, math.rad(tilt)) * CFrame.fromMatrix(Vector3.zero, right, up, back)
	model:PivotTo(face * turn)
	local lo, hi = bounds(model, face)
	local extent = hi - lo
	model:ScaleTo(model:GetScale() * math.min(fitW / extent.X, fitH / extent.Y))
	lo, hi = bounds(model, face)
	local mid = (lo + hi) / 2
	local offset = Vector3.new(center.X - mid.X, center.Y - mid.Y, 0.06 - lo.Z)
	model:PivotTo(model:GetPivot() + face:VectorToWorldSpace(offset))
end

-- Hand tools on a pegboard, in a grid of up to 4 columns, each under its
-- price tag. `boardCenter`: the pegboard's centre (its slab is 0.25 thick).
-- Returns each tool's hook (where its tag/prompt goes).
local function hang(folder: Instance, boardCenter: CFrame, boardW: number, boardH: number, hand: { string }): { CFrame }
	local face = boardCenter * CFrame.new(0, 0, 0.125)
	local columns = math.min(#hand, 4)
	local rows = math.ceil(#hand / columns)
	local cellW, cellH = boardW / columns, boardH / rows
	local hooks = {}
	for i, id in hand do
		local col = (i - 1) % columns
		local row = math.floor((i - 1) / columns)
		local x = (col - (columns - 1) / 2) * cellW
		local top = boardH / 2 - row * cellH
		hooks[i] = boardCenter * CFrame.new(x, top - 0.35 * cellH, 0.35)
		-- Area under the tag; long tools lie along its diagonal.
		local fitW, fitH = cellW * 0.82, cellH * 0.62
		local model = ToolModels.Build(id)
		anchorAll(model)
		local _, size = model:GetBoundingBox()
		local long = math.max(size.X, size.Y, size.Z) / math.max(math.min(size.X, size.Y, size.Z), 0.1)
		local tilt = if long > 3 then math.deg(math.atan2(fitW, fitH)) * 0.75 else 0
		mount(model, face, Vector2.new(x, top - cellH + 0.12 + fitH / 2), fitW, fitH, tilt)
		model.Name = "Display_" .. id
		model.Parent = folder
	end
	return hooks
end

-- The tool on a wall plaque: diagonal, filling the board.
local function mountPlaque(plaque: Instance, board: BasePart, toolId: string)
	local model = ToolModels.Build(toolId)
	anchorAll(model)
	local face = board.CFrame * CFrame.new(0, 0, board.Size.Z / 2)
	mount(model, face, Vector2.zero, board.Size.X * 0.82, board.Size.Y * 0.78, 145)
	model.Name = "Display_" .. toolId
	model.Parent = plaque
end

-- Parks a ground tool (built at the origin) with the mower itself on `spot`
-- (+Z of spot toward the player). Returns its footprint.
local function park(folder: Instance, id: string, spot: CFrame): Model
	local model = ToolModels.Build(id)
	anchorAll(model)
	model:PivotTo(spot)
	local lo, hi = bounds(model, spot)
	local mid = (lo + hi) / 2
	model:PivotTo(model:GetPivot() + spot:VectorToWorldSpace(Vector3.new(-mid.X, -lo.Y, -mid.Z)))
	model.Name = "Display_" .. id
	model.Parent = folder
	return model
end

local function parkedWidth(id: string): number
	local probe = ToolModels.Build(id)
	local _, size = probe:GetBoundingBox()
	probe:Destroy()
	return size.X
end

-- The prompt + tag holder for one item.
local function slot(parent: Instance, toolId: string, at: CFrame, tagHeight: number): Part
	local def = Tools.ById[toolId]
	local holder = Props.make("ShopItem", parent, {
		Size = Vector3.new(1.5, 1.5, 1.5),
		CFrame = at,
		Color = Color3.new(1, 1, 1),
		Transparency = 1,
		Solid = false,
	})
	holder:SetAttribute("ToolId", toolId)
	holder:SetAttribute("Price", def.Price)
	holder:SetAttribute("RequiredZone", def.RequiredZone)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopItemPrompt"
	prompt.ObjectText = def.DisplayName
	prompt.ActionText = "Buy"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = holder

	local tag = Instance.new("BillboardGui")
	tag.Name = "PriceTag"
	-- Sized in studs (not pixels): tags of neighbouring tools never grow
	-- into each other when seen from further away.
	tag.Size = UDim2.fromScale(2.4, 0.9)
	tag.StudsOffsetWorldSpace = Vector3.new(0, tagHeight, 0)
	tag.MaxDistance = 28
	tag.LightInfluence = 0
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(250, 244, 226)
	frame.Parent = tag
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	local name = Instance.new("TextLabel")
	name.Name = "ItemName"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, -8, 0.5, 0)
	name.Position = UDim2.fromOffset(4, 2)
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextColor3 = Color3.fromRGB(60, 44, 30)
	name.Text = def.DisplayName
	name.Parent = frame
	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Size = UDim2.new(1, -8, 0.45, 0)
	status.Position = UDim2.new(0, 4, 0.5, 0)
	status.Font = Enum.Font.GothamBlack
	status.TextScaled = true
	status.TextColor3 = Color3.fromRGB(40, 140, 60)
	status.Text = "$" .. def.Price
	status.Parent = frame
	tag.Parent = holder
	return holder
end

-- Builds the display for `toolIds` (hand tools on the board, ground tools
-- parked in front) under `parent`, in frame `frame`.
function ShopDisplay.Build(parent: Instance, frame: CFrame, toolIds: { string }, options: Options?)
	local o = options or {}
	local boardW, boardH = o.BoardWidth or 10, o.BoardHeight or 6
	local boardLift = o.BoardLift or 1.5
	local boardX = o.BoardOffsetX or 0
	local folder = Props.model("ToolWall", parent)

	local hand, ground = {}, {}
	for _, id in toolIds do
		if Tools.ById[id] then
			local kind = ToolModels.KindOf(id)
			table.insert(if ToolModels.Kinds[kind].Ground then ground else hand, id)
		end
	end

	if #hand > 0 then
		local boardCenter = frame * CFrame.new(boardX, boardLift + boardH / 2, 0.15)
		Props.make("Pegboard", folder, {
			Size = Vector3.new(boardW, boardH, 0.25),
			CFrame = boardCenter,
			Color = Color3.fromRGB(196, 160, 112),
			Material = Enum.Material.WoodPlanks,
		})
		-- Frame trim
		for _, y in { -1, 1 } do
			Props.make("Trim", folder, {
				Size = Vector3.new(boardW + 0.4, 0.3, 0.35),
				CFrame = boardCenter * CFrame.new(0, y * (boardH / 2 + 0.1), 0.05),
				Color = Color3.fromRGB(112, 78, 50),
				Material = Enum.Material.Wood,
			})
		end
		for i, hook in hang(folder, boardCenter, boardW, boardH, hand) do
			slot(folder, hand[i], hook * CFrame.new(0, -0.8, 0.6), 1.4)
		end
	end

	local parkX = o.ParkOffsetX or (boardW / 2 + 4)
	local parkZ = o.ParkDistance or 6
	local cursor = parkX
	for i, id in ground do
		if i > (o.MaxParked or 3) then
			break
		end
		local width = parkedWidth(id)
		local spot = frame * CFrame.new(cursor + width / 2, 0, parkZ) * CFrame.Angles(0, math.rad(180), 0)
		cursor += width + 2
		park(folder, id, spot)
		slot(folder, id, spot * CFrame.new(0, 1.5, 0), 3)
	end
	return folder
end

-- One tool on its own wall plaque: wooden frame, name sign above, the tool
-- mounted diagonally, a price tag (prompt + per-player status) below.
-- `frame`: center of the plaque on the wall, +Z out of the wall.
-- Featured plaques get a gold frame and a warm glow.
function ShopDisplay.BuildPlaque(parent: Instance, frame: CFrame, toolId: string, featured: boolean?)
	local def = Tools.ById[toolId]
	if not def then
		return
	end
	local plaque = Props.model("Plaque_" .. toolId, parent)
	local woodColor = Color3.fromRGB(196, 150, 102)
	local trimColor = if featured then Color3.fromRGB(240, 190, 60) else Color3.fromRGB(112, 78, 50)
	local w, h = 6.4, 5
	Props.make("Board", plaque, {
		Size = Vector3.new(w, h, 0.25),
		CFrame = frame * CFrame.new(0, 0, 0.12),
		Color = woodColor,
		Material = Enum.Material.WoodPlanks,
	})
	for _, spec in { { 0, h / 2, w + 0.3, 0.3 }, { 0, -h / 2, w + 0.3, 0.3 }, { -w / 2, 0, 0.3, h }, { w / 2, 0, 0.3, h } } do
		Props.make("Trim", plaque, {
			Size = Vector3.new(spec[3], spec[4], 0.4),
			CFrame = frame * CFrame.new(spec[1], spec[2], 0.2),
			Color = trimColor,
			Material = if featured then Enum.Material.Metal else Enum.Material.Wood,
		})
	end
	if featured then
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 200, 110)
		glow.Range = 9
		glow.Brightness = 1.2
		glow.Parent = plaque:FindFirstChild("Board")
	end

	local sign = Props.make("NameSign", plaque, {
		Size = Vector3.new(5.6, 1.4, 0.2),
		CFrame = frame * CFrame.new(0, h / 2 + 1, 0.3),
		Color = Color3.fromRGB(240, 222, 180),
		Material = Enum.Material.WoodPlanks,
	})
	Props.label(sign, Enum.NormalId.Back, def.DisplayName:upper(), Color3.fromRGB(90, 56, 30))

	mountPlaque(plaque, plaque:FindFirstChild("Board") :: BasePart, toolId)

	-- Price tag: holds the prompt and the per-player status text.
	local tag = Props.make("ShopItem", plaque, {
		Size = Vector3.new(4, 1.2, 0.2),
		CFrame = frame * CFrame.new(0, -h / 2 - 0.9, 0.3),
		Color = Color3.fromRGB(70, 50, 34),
		Material = Enum.Material.Wood,
	})
	tag:SetAttribute("ToolId", toolId)
	tag:SetAttribute("Price", def.Price)
	tag:SetAttribute("RequiredZone", def.RequiredZone)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.2
	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Size = UDim2.fromScale(1, 1)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.FredokaOne
	status.TextScaled = true
	status.TextColor3 = Color3.fromRGB(255, 220, 90)
	status.Text = "$" .. def.Price
	status.Parent = gui
	gui.Parent = tag

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopItemPrompt"
	prompt.ObjectText = def.DisplayName
	prompt.ActionText = "Buy"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = tag
	return plaque
end

-- Ground tools (mowers) parked in a row, each with a floating price tag.
-- `frame`: start of the row on the ground, +X along the row.
function ShopDisplay.Park(parent: Instance, frame: CFrame, toolIds: { string }, maxCount: number?)
	local folder = Props.model("ParkedMowers", parent)
	local cursor = 0
	for i, id in toolIds do
		if i > (maxCount or 3) then
			break
		end
		local width = parkedWidth(id)
		local spot = frame * CFrame.new(cursor + width / 2, 0, 0) * CFrame.Angles(0, math.rad(180), 0)
		cursor += width + 2
		park(folder, id, spot)
		slot(folder, id, spot * CFrame.new(0, 1.5, 0), 3)
	end
	return folder
end

-- Splits tool ids into hand tools and ground tools (mowers).
function ShopDisplay.Split(toolIds: { string }): ({ string }, { string })
	local hand, ground = {}, {}
	for _, id in toolIds do
		if Tools.ById[id] then
			table.insert(if ToolModels.Kinds[ToolModels.KindOf(id)].Ground then ground else hand, id)
		end
	end
	return hand, ground
end

-- Tool ids a shop in zone number `zoneIndex` sells (data-driven: every tool
-- whose RequiredZone is that zone).
function ShopDisplay.ToolsForZone(zoneIndex: number): { string }
	local ids = {}
	for _, def in Tools.List do
		if def.RequiredZone == zoneIndex then
			table.insert(ids, def.Id)
		end
	end
	return ids
end

-- Rebuilds every tool display already in the world (baked into the place
-- or built earlier) with the current models: hand tools re-hung on their
-- pegboard or plaque, mowers re-parked where they stood. Tags, prompts and
-- boards stay. Lets new tool art show up without re-baking the map.
function ShopDisplay.Refresh()
	local byParent: { [Instance]: { Model } } = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and string.match(d.Name, "^Display_") and d.Parent then
			local list = byParent[d.Parent :: Instance] or {}
			table.insert(list, d)
			byParent[d.Parent :: Instance] = list
		end
	end
	local order: { [string]: number } = {}
	for i, def in Tools.List do
		order[def.Id] = i
	end
	for parent, displays in byParent do
		local hand: { string } = {}
		for _, old in displays do
			local id = string.sub(old.Name, #"Display_" + 1)
			if not Tools.ById[id] then
				continue
			end
			if ToolModels.Kinds[ToolModels.KindOf(id)].Ground then
				local pivot = old:GetPivot()
				local spot = CFrame.new(pivot.Position) * CFrame.fromOrientation(0, select(2, pivot:ToOrientation()), 0)
				local lo, hi = bounds(old, spot)
				local mid = (lo + hi) / 2
				old:Destroy()
				park(parent, id, spot * CFrame.new(mid.X, lo.Y, mid.Z))
			else
				table.insert(hand, id)
				old:Destroy()
			end
		end
		table.sort(hand, function(a, b)
			return order[a] < order[b]
		end)
		local pegboard = parent:FindFirstChild("Pegboard")
		local board = parent:FindFirstChild("Board")
		if pegboard and pegboard:IsA("BasePart") and #hand > 0 then
			hang(parent, pegboard.CFrame, pegboard.Size.X, pegboard.Size.Y, hand)
		elseif board and board:IsA("BasePart") and #hand == 1 then
			mountPlaque(parent, board, hand[1])
		end
	end
end

return ShopDisplay
