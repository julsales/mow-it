--!strict
-- A walk-in shop building: wood floor, log-style walls with a door you can
-- walk through, beams and hanging lanterns, a fireplace, shelves, a counter
-- with a shopkeeper, and the tools on wall plaques (ShopDisplay). Mowers
-- park outside by the porch. "TOOL SHOP" sign over the door.
--
-- Reused for any area whose shop is a building (MapLayout ShopAt). Frame:
-- origin on the ground at the building's center, +Z = the front (door).

local Props = require(script.Parent.Props)
local ShopDisplay = require(script.Parent.ShopDisplay)

local ShopInterior = {}

local W, D, H = 36, 26, 11 -- inside size
local T = 1 -- wall thickness
local DOOR_W, DOOR_H = 6, 8
local FLOOR = 0.6

local LOG = Color3.fromRGB(176, 124, 76)
local LOG_DARK = Color3.fromRGB(120, 82, 50)
local FLOOR_WOOD = Color3.fromRGB(160, 104, 62)
local ROOF = Color3.fromRGB(96, 64, 44)
local STONE = Color3.fromRGB(140, 136, 130)
local WARM = Color3.fromRGB(255, 186, 110)

local function lamp(parent: Instance, cf: CFrame, range: number)
	local body = Props.make("Lantern", parent, {
		Size = Vector3.new(0.8, 1.1, 0.8),
		CFrame = cf,
		Color = Color3.fromRGB(255, 214, 120),
		Material = Enum.Material.Neon,
		Solid = false,
	})
	Props.make("LanternCap", parent, {
		Size = Vector3.new(1, 0.25, 1),
		CFrame = cf * CFrame.new(0, 0.65, 0),
		Color = Color3.fromRGB(40, 36, 32),
		Material = Enum.Material.Metal,
		Solid = false,
	})
	Props.make("Chain", parent, {
		Size = Vector3.new(0.1, 1.6, 0.1),
		CFrame = cf * CFrame.new(0, 1.55, 0),
		Color = Color3.fromRGB(40, 36, 32),
		Material = Enum.Material.Metal,
		Solid = false,
	})
	local light = Instance.new("PointLight")
	light.Color = WARM
	light.Range = range
	light.Brightness = 1.4
	light.Shadows = false
	light.Parent = body
end

-- One wall slab (local center and size).
local function wall(parent: Instance, cf: CFrame, center: Vector3, size: Vector3)
	Props.make("Wall", parent, {
		Size = size,
		CFrame = cf * CFrame.new(center),
		Color = LOG,
		Material = Enum.Material.WoodPlanks,
	})
end

function ShopInterior.Build(parent: Instance, cf: CFrame, toolIds: { string }, title: string, keeper: string)
	local m = Props.model("ShopBuilding", parent)
	local y0 = FLOOR

	-- Floor and porch.
	Props.make("Floor", m, {
		Size = Vector3.new(W + 2 * T, FLOOR, D + 2 * T),
		CFrame = cf * CFrame.new(0, FLOOR / 2, 0),
		Color = FLOOR_WOOD,
		Material = Enum.Material.WoodPlanks,
	})
	Props.make("Porch", m, {
		Size = Vector3.new(W * 0.6, FLOOR, 5),
		CFrame = cf * CFrame.new(0, FLOOR / 2, D / 2 + T + 2.5),
		Color = FLOOR_WOOD,
		Material = Enum.Material.WoodPlanks,
	})

	-- Walls: back, sides, and the front split around the door.
	local wy = y0 + H / 2
	wall(m, cf, Vector3.new(0, wy, -D / 2 - T / 2), Vector3.new(W + 2 * T, H, T))
	wall(m, cf, Vector3.new(-W / 2 - T / 2, wy, 0), Vector3.new(T, H, D))
	wall(m, cf, Vector3.new(W / 2 + T / 2, wy, 0), Vector3.new(T, H, D))
	local side = (W + 2 * T - DOOR_W) / 2
	wall(m, cf, Vector3.new(-(DOOR_W / 2 + side / 2), wy, D / 2 + T / 2), Vector3.new(side, H, T))
	wall(m, cf, Vector3.new(DOOR_W / 2 + side / 2, wy, D / 2 + T / 2), Vector3.new(side, H, T))
	wall(m, cf, Vector3.new(0, y0 + DOOR_H + (H - DOOR_H) / 2, D / 2 + T / 2), Vector3.new(DOOR_W, H - DOOR_H, T))
	-- Log bands on the outside, for a cabin look.
	for i = 1, 4 do
		local y = y0 + i * (H / 5)
		for _, z in { -D / 2 - T - 0.15, D / 2 + T + 0.15 } do
			Props.make("Log", m, {
				Size = Vector3.new(W + 2 * T + 0.6, 0.35, 0.3),
				CFrame = cf * CFrame.new(0, y, z),
				Color = LOG_DARK,
				Material = Enum.Material.Wood,
				Solid = false,
			})
		end
	end
	-- Windows on the front, either side of the door.
	for _, x in { -W / 4 - 2, W / 4 + 2 } do
		Props.make("Window", m, {
			Size = Vector3.new(5, 3.6, T + 0.1),
			CFrame = cf * CFrame.new(x, y0 + 5.5, D / 2 + T / 2),
			Color = Color3.fromRGB(150, 206, 240),
			Material = Enum.Material.Glass,
			Transparency = 0.35,
		})
	end

	-- Ceiling, beams and a gable roof (two wedge halves).
	Props.make("Ceiling", m, {
		Size = Vector3.new(W + 2 * T, 0.5, D + 2 * T),
		CFrame = cf * CFrame.new(0, y0 + H + 0.25, 0),
		Color = LOG,
		Material = Enum.Material.WoodPlanks,
	})
	for _, x in { -W / 3, 0, W / 3 } do
		Props.make("Beam", m, {
			Size = Vector3.new(1, 1, D),
			CFrame = cf * CFrame.new(x, y0 + H - 0.5, 0),
			Color = LOG_DARK,
			Material = Enum.Material.Wood,
		})
	end
	local rise = 7
	for _, dir in { 1, -1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Roof"
		wedge.Anchored = true
		wedge.Size = Vector3.new(W + 4, rise, D / 2 + 2)
		wedge.CFrame = cf * CFrame.new(0, y0 + H + 0.5 + rise / 2, dir * (D / 4 + 1)) * CFrame.Angles(0, if dir > 0 then 0 else math.pi, 0)
		wedge.Color = ROOF
		wedge.Material = Enum.Material.WoodPlanks
		wedge.Parent = m
	end

	-- Fireplace on the back wall.
	local back = -D / 2
	Props.make("Chimney", m, {
		Size = Vector3.new(7, H, 2),
		CFrame = cf * CFrame.new(0, y0 + H / 2, back + 1),
		Color = STONE,
		Material = Enum.Material.Slate,
	})
	local hearth = Props.make("Hearth", m, {
		Size = Vector3.new(4, 3, 0.4),
		CFrame = cf * CFrame.new(0, y0 + 1.5, back + 2.05),
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
	glow.Brightness = 1.6
	glow.Parent = hearth
	Props.make("Mantel", m, {
		Size = Vector3.new(8, 0.5, 2.6),
		CFrame = cf * CFrame.new(0, y0 + 4.2, back + 1.3),
		Color = LOG_DARK,
		Material = Enum.Material.Wood,
	})

	-- Lanterns.
	for _, x in { -W / 3, W / 3 } do
		lamp(m, cf * CFrame.new(x, y0 + H - 3, 0), 26)
	end

	-- Shelves with jars and boxes in a back corner.
	for i, y in { 3, 5.5 } do
		Props.make("Shelf", m, {
			Size = Vector3.new(6, 0.3, 1.4),
			CFrame = cf * CFrame.new(-W / 2 + 4, y0 + y, back + 0.8),
			Color = LOG_DARK,
			Material = Enum.Material.Wood,
		})
		for j = 0, 2 do
			Props.make("Jar", m, {
				Size = Vector3.new(0.8, 1 + (i + j) % 2 * 0.4, 0.8),
				CFrame = cf * CFrame.new(-W / 2 + 2 + j * 2, y0 + y + 0.7, back + 0.8),
				Color = ({ Color3.fromRGB(110, 170, 90), Color3.fromRGB(220, 180, 80), Color3.fromRGB(180, 90, 70) })[j + 1],
				Material = Enum.Material.SmoothPlastic,
				Solid = false,
			})
		end
	end

	-- Counter by the door with the shopkeeper.
	local counterCf = cf * CFrame.new(W / 2 - 6, y0, D / 2 - 6)
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

	-- Tools on plaques: two on each side wall, two flanking the fireplace.
	-- The most expensive one gets the featured (gold) frame.
	local hand, ground = ShopDisplay.Split(toolIds)
	local slots = {
		cf * CFrame.new(-7.5, y0 + 5, back + 0.05),
		cf * CFrame.new(7.5, y0 + 5, back + 0.05),
		cf * CFrame.new(-W / 2 + 0.05, y0 + 5, -5) * CFrame.Angles(0, math.rad(90), 0),
		cf * CFrame.new(-W / 2 + 0.05, y0 + 5, 4) * CFrame.Angles(0, math.rad(90), 0),
		cf * CFrame.new(W / 2 - 0.05, y0 + 5, -5) * CFrame.Angles(0, -math.rad(90), 0),
		cf * CFrame.new(W / 2 - 0.05, y0 + 5, 4) * CFrame.Angles(0, -math.rad(90), 0),
	}
	local featured = hand[#hand]
	for i, id in hand do
		if slots[i] then
			ShopDisplay.BuildPlaque(m, slots[i], id, id == featured)
		end
	end

	-- Mowers parked outside, to the right of the porch.
	ShopDisplay.Park(m, cf * CFrame.new(W * 0.3 + 2, 0, D / 2 + T + 5), ground, 3)

	-- Sign over the door.
	local sign = Props.make("ShopSign", m, {
		Size = Vector3.new(10, 1.8, 0.4),
		CFrame = cf * CFrame.new(0, y0 + DOOR_H + 1.4, D / 2 + T + 0.3),
		Color = Color3.fromRGB(110, 72, 42),
		Material = Enum.Material.WoodPlanks,
	})
	Props.label(sign, Enum.NormalId.Back, title:upper(), Color3.fromRGB(255, 196, 90))
	return m
end

ShopInterior.Radius = math.max(W, D) / 2 + 8

return ShopInterior
