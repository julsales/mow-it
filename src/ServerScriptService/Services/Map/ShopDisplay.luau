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
	tag.Size = UDim2.fromOffset(120, 44)
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
		local columns = math.min(#hand, 4)
		local rows = math.ceil(#hand / columns)
		for i, id in hand do
			local col = (i - 1) % columns
			local row = math.floor((i - 1) / columns)
			local x = (col - (columns - 1) / 2) * (boardW / columns)
			local y = boardH / 2 - (row + 0.35) * (boardH / rows)
			local hook = boardCenter * CFrame.new(x, y, 0.35)
			local model = ToolModels.Build(id)
			anchorAll(model)
			-- Hang it: grip at the hook, tool pointing down the board.
			model:PivotTo(hook * CFrame.Angles(-math.rad(90), 0, 0))
			model.Name = "Display_" .. id
			model.Parent = folder
			slot(folder, id, hook * CFrame.new(0, -0.8, 0.6), 1.4)
		end
	end

	local parkX = o.ParkOffsetX or (boardW / 2 + 4)
	local parkZ = o.ParkDistance or 6
	local cursor = parkX
	for i, id in ground do
		if i > (o.MaxParked or 3) then
			break
		end
		local model = ToolModels.Build(id)
		anchorAll(model)
		local _, footprint = model:GetBoundingBox()
		local spot = frame * CFrame.new(cursor + footprint.X / 2, 0, parkZ) * CFrame.Angles(0, math.rad(180), 0)
		cursor += footprint.X + 2
		-- Ground models are built with the player standing at the origin and
		-- the mower in front (-Z); park it so the mower itself sits on `spot`.
		model:PivotTo(spot * CFrame.new(0, 0, footprint.Z / 2))
		model.Name = "Display_" .. id
		model.Parent = folder
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

	-- Mount the tool flat on the board, tilted, centered by its bounding box.
	local model = ToolModels.Build(toolId)
	anchorAll(model)
	-- Display size: fill the plaque whatever size the tool is in the hand.
	local _, rawSize = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * 5 / math.max(rawSize.X, rawSize.Y, rawSize.Z))
	model:PivotTo(frame * CFrame.Angles(0, 0, math.rad(-35)) * CFrame.Angles(math.rad(90), 0, 0))
	local box = model:GetBoundingBox()
	local target = frame * CFrame.new(0, 0, 0.45)
	model:PivotTo(model:GetPivot() + (target.Position - box.Position))
	model.Name = "Display_" .. toolId
	model.Parent = plaque

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
		local model = ToolModels.Build(id)
		anchorAll(model)
		local _, footprint = model:GetBoundingBox()
		local spot = frame * CFrame.new(cursor + footprint.X / 2, 0, 0) * CFrame.Angles(0, math.rad(180), 0)
		cursor += footprint.X + 2
		model:PivotTo(spot * CFrame.new(0, 0, footprint.Z / 2))
		model.Name = "Display_" .. id
		model.Parent = folder
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

return ShopDisplay
