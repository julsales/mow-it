--!strict
-- A walk-in shop building, in two layers so each can change on its own:
--   * Shell: a Creator Store log cabin from ServerStorage/MapProps/ShopCabin
--     (audited, kept in the place file because Rojo can't sync it), scaled
--     up with its door opened; or, if that model is missing, a cabin built
--     from parts. Either way the shell reports its inside as a `Room`.
--   * Furnishing: fireplace, lanterns, shelves, a counter with the
--     shopkeeper, the tools on big wall plaques (ShopDisplay), mowers parked
--     outside and a big sign over the door. Placed from the Room, so it fits
--     any shell.
--
-- Frame `cf`: origin on the ground at the building's center, +Z = the front.

local ServerStorage = game:GetService("ServerStorage")

local Props = require(script.Parent.Props)
local ShopDisplay = require(script.Parent.ShopDisplay)

local ShopInterior = {}

export type Room = {
	Floor: CFrame, -- center of the floor surface, +Z toward the door wall
	Width: number, -- inside, along X
	Depth: number, -- inside, along Z
	Height: number, -- inside, floor to ceiling
	DoorX: number, -- door center along the front wall
	DoorHeight: number,
	FrontOutside: number, -- local Z of the outside face of the front wall
}

local LOG = Color3.fromRGB(150, 104, 68)
local LOG_DARK = Color3.fromRGB(112, 76, 48)
local FLOOR_WOOD = Color3.fromRGB(150, 98, 60)
local ROOF = Color3.fromRGB(96, 64, 44)
local STONE = Color3.fromRGB(140, 136, 130)
local WARM = Color3.fromRGB(255, 186, 110)

local CABIN_SCALE = 1.6

-- Shells ----------------------------------------------------------------------------

-- The Creator Store cabin (ShopCabin, pivot = its bounding-box center). In
-- its own space: door on the +X wall around z = 4..9, floor top at y = -9.5,
-- ceiling at y = -1, inside x -10..10 / z -10.5..10.5.
local function cabinShell(parent: Instance, cf: CFrame): Room?
	local folder = ServerStorage:FindFirstChild("MapProps")
	local template = folder and folder:FindFirstChild("ShopCabin")
	if not template or not template:IsA("Model") then
		return nil
	end
	local s = CABIN_SCALE
	local floorTop = Props.GroundTop + 1
	local shell = template:Clone()
	for _, d in shell:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	shell:ScaleTo(shell:GetScale() * s)
	-- Model +X (door wall) -> frame +Z; floor top lands on floorTop.
	local pivot = cf * CFrame.new(0, floorTop + 9.5 * s, 0) * CFrame.Angles(0, -math.rad(90), 0)
	shell:PivotTo(pivot)
	-- Open the door: remove the door panel parts (non-log parts in the
	-- doorway); keep the window on the other side of the wall.
	for _, d in shell:GetDescendants() do
		if d:IsA("BasePart") then
			local p = pivot:PointToObjectSpace(d.Position) / s
			if math.abs(p.X - 10.6) < 1.2 and p.Z > 2 and p.Y > -9.4 and p.Y < -3 and d.Material ~= Enum.Material.Wood then
				d:Destroy()
			end
		end
	end
	shell.Name = "Cabin"
	shell.Parent = parent
	return {
		Floor = cf * CFrame.new(0, floorTop, 0),
		Width = 20 * s,
		Depth = 19.5 * s,
		Height = 8.5 * s,
		DoorX = -6.5 * s, -- model z = +6.5 -> frame x = -6.5
		DoorHeight = 5 * s,
		FrontOutside = 12 * s,
	}
end

-- Fallback: a cabin built from parts.
local function partShell(parent: Instance, cf: CFrame): Room
	local W, D, H, T = 34, 26, 12, 1
	local doorW, doorH = 6, 8
	local floor = 0.6
	local function slab(name: string, center: Vector3, size: Vector3, color: Color3, material: Enum.Material)
		Props.make(name, parent, { Size = size, CFrame = cf * CFrame.new(center), Color = color, Material = material })
	end
	slab("Floor", Vector3.new(0, floor / 2, 0), Vector3.new(W + 2 * T, floor, D + 2 * T), FLOOR_WOOD, Enum.Material.WoodPlanks)
	local wy = floor + H / 2
	slab("Wall", Vector3.new(0, wy, -D / 2 - T / 2), Vector3.new(W + 2 * T, H, T), LOG, Enum.Material.Wood)
	slab("Wall", Vector3.new(-W / 2 - T / 2, wy, 0), Vector3.new(T, H, D), LOG, Enum.Material.Wood)
	slab("Wall", Vector3.new(W / 2 + T / 2, wy, 0), Vector3.new(T, H, D), LOG, Enum.Material.Wood)
	local side = (W + 2 * T - doorW) / 2
	slab("Wall", Vector3.new(-(doorW / 2 + side / 2), wy, D / 2 + T / 2), Vector3.new(side, H, T), LOG, Enum.Material.Wood)
	slab("Wall", Vector3.new(doorW / 2 + side / 2, wy, D / 2 + T / 2), Vector3.new(side, H, T), LOG, Enum.Material.Wood)
	slab("Wall", Vector3.new(0, floor + doorH + (H - doorH) / 2, D / 2 + T / 2), Vector3.new(doorW, H - doorH, T), LOG, Enum.Material.Wood)
	slab("Ceiling", Vector3.new(0, floor + H + 0.25, 0), Vector3.new(W + 2 * T, 0.5, D + 2 * T), LOG, Enum.Material.WoodPlanks)
	local rise = 7
	for _, dir in { 1, -1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Roof"
		wedge.Anchored = true
		wedge.Size = Vector3.new(W + 4, rise, D / 2 + 2)
		-- Tall side toward the ridge (the center), so the roof peaks up.
		wedge.CFrame = cf * CFrame.new(0, floor + H + 0.5 + rise / 2, dir * (D / 4 + 1)) * CFrame.Angles(0, if dir > 0 then math.pi else 0, 0)
		wedge.Color = ROOF
		wedge.Material = Enum.Material.WoodPlanks
		wedge.Parent = parent
	end
	return {
		Floor = cf * CFrame.new(0, floor, 0),
		Width = W,
		Depth = D,
		Height = H,
		DoorX = 0,
		DoorHeight = doorH,
		FrontOutside = D / 2 + T,
	}
end

-- Furnishing ----------------------------------------------------------------------

local function lamp(parent: Instance, cf: CFrame, range: number)
	local body = Props.make("Lantern", parent, {
		Size = Vector3.new(0.9, 1.2, 0.9),
		CFrame = cf,
		Color = Color3.fromRGB(255, 214, 120),
		Material = Enum.Material.Neon,
		Solid = false,
	})
	Props.make("LanternCap", parent, {
		Size = Vector3.new(1.1, 0.25, 1.1),
		CFrame = cf * CFrame.new(0, 0.7, 0),
		Color = Color3.fromRGB(40, 36, 32),
		Material = Enum.Material.Metal,
		Solid = false,
	})
	Props.make("Chain", parent, {
		Size = Vector3.new(0.1, 2, 0.1),
		CFrame = cf * CFrame.new(0, 1.8, 0),
		Color = Color3.fromRGB(40, 36, 32),
		Material = Enum.Material.Metal,
		Solid = false,
	})
	local light = Instance.new("PointLight")
	light.Color = WARM
	light.Range = range
	light.Brightness = 1.2
	light.Parent = body
end

local function furnish(m: Instance, room: Room, toolIds: { string }, title: string, keeper: string)
	local f = room.Floor
	local ground = f - Vector3.new(0, f.Y - Props.GroundTop, 0)
	local halfW, halfD = room.Width / 2, room.Depth / 2
	local back = -halfD

	-- Fireplace in the middle of the back wall.
	Props.make("Chimney", m, {
		Size = Vector3.new(6.5, room.Height, 2),
		CFrame = f * CFrame.new(0, room.Height / 2, back + 1),
		Color = STONE,
		Material = Enum.Material.Slate,
	})
	local hearth = Props.make("Hearth", m, {
		Size = Vector3.new(3.8, 3, 0.4),
		CFrame = f * CFrame.new(0, 1.5, back + 2.05),
		Color = Color3.fromRGB(30, 24, 20),
		Material = Enum.Material.SmoothPlastic,
	})
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 150, 60)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 120)
	fire.Parent = hearth
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 150, 70)
	glow.Range = 16
	glow.Brightness = 1.4
	glow.Parent = hearth
	Props.make("Mantel", m, {
		Size = Vector3.new(7.6, 0.5, 2.6),
		CFrame = f * CFrame.new(0, 4.2, back + 1.3),
		Color = LOG_DARK,
		Material = Enum.Material.Wood,
	})

	-- Lanterns from the ceiling.
	for _, x in { -halfW / 2, halfW / 2 } do
		lamp(m, f * CFrame.new(x, room.Height - 3, 0), 28)
	end

	-- Shelves with jars in the back-left corner.
	for i, y in { 3, 5.5 } do
		Props.make("Shelf", m, {
			Size = Vector3.new(5, 0.3, 1.4),
			CFrame = f * CFrame.new(-halfW + 3, y, back + 0.8),
			Color = LOG_DARK,
			Material = Enum.Material.Wood,
		})
		for j = 0, 2 do
			Props.make("Jar", m, {
				Size = Vector3.new(0.8, 1 + (i + j) % 2 * 0.4, 0.8),
				CFrame = f * CFrame.new(-halfW + 1.5 + j * 1.5, y + 0.7, back + 0.8),
				Color = ({ Color3.fromRGB(110, 170, 90), Color3.fromRGB(220, 180, 80), Color3.fromRGB(180, 90, 70) })[j + 1],
				Material = Enum.Material.SmoothPlastic,
				Solid = false,
			})
		end
	end

	-- Counter beside the door, the shopkeeper behind it.
	local counterX = if room.DoorX < 0 then halfW - 6 else -halfW + 6
	local counterCf = f * CFrame.new(counterX, 0, halfD - 6)
	local counter = Props.make("Counter", m, {
		Size = Vector3.new(7, 3.4, 2.4),
		CFrame = counterCf * CFrame.new(0, 1.7, 0),
		Color = LOG_DARK,
		Material = Enum.Material.WoodPlanks,
	})
	Props.make("CounterTop", m, {
		Size = Vector3.new(7.4, 0.3, 2.8),
		CFrame = counterCf * CFrame.new(0, 3.55, 0),
		Color = LOG,
		Material = Enum.Material.Wood,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenShopPrompt"
	prompt.ObjectText = title
	prompt.ActionText = "Browse all"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	Props.npc(m, counterCf * CFrame.new(0, 0, -2.6) * CFrame.Angles(0, math.pi, 0), keeper, Color3.fromRGB(70, 110, 170))

	-- Tools on big plaques: two flanking the fireplace, two on each side
	-- wall. The most expensive one gets the featured gold frame.
	local hand, mowers = ShopDisplay.Split(toolIds)
	local y = math.min(5.6, room.Height - 4)
	local sideZ = math.min(6, halfD - 5)
	local slots = {
		f * CFrame.new(-(3.25 + 4.2), y, back + 0.1),
		f * CFrame.new(3.25 + 4.2, y, back + 0.1),
		f * CFrame.new(-halfW + 0.1, y, -sideZ) * CFrame.Angles(0, math.rad(90), 0),
		f * CFrame.new(-halfW + 0.1, y, sideZ) * CFrame.Angles(0, math.rad(90), 0),
		f * CFrame.new(halfW - 0.1, y, -sideZ) * CFrame.Angles(0, -math.rad(90), 0),
		f * CFrame.new(halfW - 0.1, y, sideZ) * CFrame.Angles(0, -math.rad(90), 0),
	}
	local featured = hand[#hand]
	for i, id in hand do
		if slots[i] then
			ShopDisplay.BuildPlaque(m, slots[i], id, id == featured)
		end
	end

	-- Mowers parked outside, on the side away from the door.
	local parkX = if room.DoorX < 0 then 2 else halfW * 0.4
	ShopDisplay.Park(m, ground * CFrame.new(parkX, 0, room.FrontOutside + 5), mowers, 3)

	-- Big sign over the door, outside.
	local sign = Props.make("ShopSign", m, {
		Size = Vector3.new(14, 3, 0.5),
		CFrame = f * CFrame.new(room.DoorX, room.DoorHeight + 2.4, room.FrontOutside + 0.4),
		Color = Color3.fromRGB(110, 72, 42),
		Material = Enum.Material.WoodPlanks,
	})
	Props.label(sign, Enum.NormalId.Back, title:upper(), Color3.fromRGB(255, 196, 90))
end

function ShopInterior.Build(parent: Instance, cf: CFrame, toolIds: { string }, title: string, keeper: string)
	local m = Props.model("ShopBuilding", parent)
	local room = cabinShell(m, cf) or partShell(m, cf)
	furnish(m, room, toolIds, title, keeper)
	return m
end

ShopInterior.Radius = 28

return ShopInterior
