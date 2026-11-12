--!strict
-- A walk-in shop building, in two layers so each can change on its own:
--   * Shell (logShell): a log cabin built from parts, with a centered door,
--     windows, a porch with steps and a chimney. Reports its inside as a Room.
--   * Furnishing: fireplace, lanterns, shelves, a counter with the
--     shopkeeper, the tools on big wall plaques (ShopDisplay), mowers parked
--     outside and a big sign over the door, placed from the Room.
--
-- Frame `cf`: origin on the ground at the building's center, +Z = the front.

local Props = require(script.Parent.Props)
local ShopDisplay = require(script.Parent.ShopDisplay)

local ShopInterior = {}

export type Room = {
	Entrance: CFrame, -- on the ground just past the bottom step (paths end here)
	SignAt: CFrame, -- where the shop sign hangs, in front of everything
	Floor: CFrame, -- center of the floor surface, +Z toward the door wall
	Width: number, -- inside, along X
	Depth: number, -- inside, along Z
	Height: number, -- inside, floor to ceiling
	DoorX: number, -- door center along the front wall
	DoorHeight: number,
	FrontOutside: number, -- local Z of the outside face of the front wall
}

local LOG = Color3.fromRGB(146, 100, 62)
local LOG_DARK = Color3.fromRGB(112, 76, 48)
local FLOOR_WOOD = Color3.fromRGB(150, 98, 60)
local ROOF = Color3.fromRGB(104, 68, 46)
local STONE = Color3.fromRGB(140, 136, 130)
local WARM = Color3.fromRGB(255, 186, 110)

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

-- Shell: a log cabin built from parts ------------------------------------------------
--
-- Walls are stacked horizontal logs (cylinders) whose ends cross at the
-- corners; doors and windows are real openings cut out of the log rows,
-- with frames, sills and shutters sticking out for depth. A raised floor,
-- a covered porch on posts with railings and steps, a gable roof with
-- overhangs and a stone chimney finish it.

local W, D = 32, 24 -- inside width (X) and depth (Z)
local LOG_D = 2 -- log diameter
local ROWS = 6 -- logs per wall -> wall height 12
local FLOOR = 1.6 -- floor height above the ground
local DOOR_W, DOOR_H = 5, 8
local RISE = 7 -- roof height above the walls

type Opening = { X1: number, X2: number, Y1: number, Y2: number }

-- One log wall along the local X axis of `line` (origin = wall center line
-- at floor level), cut around `openings` (in the same local units).
local function logWall(parent: Instance, line: CFrame, length: number, openings: { Opening })
	for row = 0, ROWS - 1 do
		local y = LOG_D / 2 + row * LOG_D
		-- Start with the full log (+ overhang past the corners), subtract openings.
		local pieces = { { -length / 2 - 1.6, length / 2 + 1.6 } }
		for _, o in openings do
			if y > o.Y1 and y < o.Y2 then
				local nextPieces = {}
				for _, piece in pieces do
					if o.X2 <= piece[1] or o.X1 >= piece[2] then
						table.insert(nextPieces, piece)
					else
						if o.X1 > piece[1] then
							table.insert(nextPieces, { piece[1], o.X1 })
						end
						if o.X2 < piece[2] then
							table.insert(nextPieces, { o.X2, piece[2] })
						end
					end
				end
				pieces = nextPieces
			end
		end
		for k, piece in pieces do
			local len = piece[2] - piece[1]
			if len > 0.3 then
				-- Natural brown, a little different per log (bark texture comes
				-- from the Wood material).
				local shade = ((row * 7 + k * 3) % 5) / 5
				Props.make("Log", parent, {
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(len, LOG_D, LOG_D),
					CFrame = line * CFrame.new((piece[1] + piece[2]) / 2, y, 0),
					Color = LOG:Lerp(LOG_DARK, shade * 0.5),
					Material = Enum.Material.Wood,
				})
				-- Light cut ends where logs stick out past the corners.
				for _, endX in { piece[1], piece[2] } do
					if math.abs(math.abs(endX) - (length / 2 + 1.6)) < 0.01 then
						Props.make("LogEnd", parent, {
							Shape = Enum.PartType.Cylinder,
							Size = Vector3.new(0.12, LOG_D - 0.25, LOG_D - 0.25),
							CFrame = line * CFrame.new(endX + (if endX > 0 then 0.05 else -0.05), y, 0),
							Color = Color3.fromRGB(214, 176, 124),
							Material = Enum.Material.Wood,
							Solid = false,
						})
					end
				end
			end
		end
	end
end

-- Window: frame, glass, sill and two open shutters, on a wall whose local
-- +Z points outside.
local function window(parent: Instance, line: CFrame, x: number, o: Opening)
	local w, h = o.X2 - o.X1, o.Y2 - o.Y1
	local c = line * CFrame.new(x, (o.Y1 + o.Y2) / 2, 0)
	Props.make("Glass", parent, {
		Size = Vector3.new(w, h, 0.15),
		CFrame = c,
		Color = Color3.fromRGB(160, 210, 235),
		Material = Enum.Material.Glass,
		Transparency = 0.45,
	})
	for _, spec in { { 0, h / 2 + 0.2, w + 0.8, 0.4 }, { 0, -h / 2 - 0.2, w + 0.8, 0.4 }, { -w / 2 - 0.2, 0, 0.4, h }, { w / 2 + 0.2, 0, 0.4, h }, { 0, 0, 0.25, h } } do
		Props.make("WindowFrame", parent, {
			Size = Vector3.new(spec[3], spec[4], LOG_D + 0.4),
			CFrame = c * CFrame.new(spec[1], spec[2], 0),
			Color = Color3.fromRGB(240, 232, 214),
			Material = Enum.Material.Wood,
		})
	end
	Props.make("Sill", parent, {
		Size = Vector3.new(w + 1.4, 0.35, 1.2),
		CFrame = c * CFrame.new(0, -h / 2 - 0.55, LOG_D / 2 + 0.3),
		Color = LOG_DARK,
		Material = Enum.Material.Wood,
	})
	for _, side in { -1, 1 } do
		Props.make("Shutter", parent, {
			Size = Vector3.new(w / 2 + 0.2, h + 0.6, 0.25),
			CFrame = c * CFrame.new(side * (w / 2 + w / 4 + 0.8), 0, LOG_D / 2 + 0.35) * CFrame.Angles(0, side * math.rad(-12), 0),
			Color = Color3.fromRGB(70, 120, 80),
			Material = Enum.Material.WoodPlanks,
		})
	end
end

local function logShell(parent: Instance, cf: CFrame): Room
	local floorCf = cf * CFrame.new(0, FLOOR, 0)
	local wallH = ROWS * LOG_D
	local halfW, halfD = W / 2 + LOG_D / 2, D / 2 + LOG_D / 2 -- wall center lines

	-- Stone foundation and plank floor.
	Props.make("Foundation", parent, {
		Size = Vector3.new(W + 2 * LOG_D + 1, FLOOR, D + 2 * LOG_D + 1),
		CFrame = cf * CFrame.new(0, FLOOR / 2, 0),
		Color = Color3.fromRGB(128, 122, 116),
		Material = Enum.Material.Cobblestone,
	})
	Props.make("Floor", parent, {
		Size = Vector3.new(W + 0.5, 0.2, D + 0.5),
		CFrame = floorCf * CFrame.new(0, 0.1, 0),
		Color = FLOOR_WOOD,
		Material = Enum.Material.WoodPlanks,
	})

	-- Walls. Each wall's local +Z points outside.
	local winH = { Y1 = 4, Y2 = 8 }
	local front = floorCf * CFrame.new(0, 0, halfD)
	local back = floorCf * CFrame.new(0, 0, -halfD) * CFrame.Angles(0, math.pi, 0)
	local left = floorCf * CFrame.new(-halfW, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0)
	local right = floorCf * CFrame.new(halfW, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
	local door = { X1 = -DOOR_W / 2, X2 = DOOR_W / 2, Y1 = 0, Y2 = DOOR_H }
	local frontWindows = {
		-- Far enough from the door that shutters clear the door frame.
		{ X1 = -11.5, X2 = -7, Y1 = winH.Y1, Y2 = winH.Y2 },
		{ X1 = 7, X2 = 11.5, Y1 = winH.Y1, Y2 = winH.Y2 },
	}
	logWall(parent, front, W, { door, frontWindows[1], frontWindows[2] })
	logWall(parent, back, W, {})
	local sideWindow = { X1 = -2.25, X2 = 2.25, Y1 = winH.Y1, Y2 = winH.Y2 }
	logWall(parent, left, D, { sideWindow })
	logWall(parent, right, D, { sideWindow })
	for _, o in frontWindows do
		window(parent, front, (o.X1 + o.X2) / 2, o)
	end
	window(parent, left, 0, sideWindow)
	window(parent, right, 0, sideWindow)

	-- Door: frame and a plank door swung open into the room.
	for _, spec in { { -DOOR_W / 2 - 0.25, DOOR_H / 2, 0.5, DOOR_H }, { DOOR_W / 2 + 0.25, DOOR_H / 2, 0.5, DOOR_H }, { 0, DOOR_H + 0.25, DOOR_W + 1, 0.5 } } do
		Props.make("DoorFrame", parent, {
			Size = Vector3.new(spec[3], spec[4], LOG_D + 0.5),
			CFrame = front * CFrame.new(spec[1], spec[2], 0),
			Color = LOG_DARK,
			Material = Enum.Material.Wood,
		})
	end
	Props.make("Door", parent, {
		Size = Vector3.new(DOOR_W - 0.2, DOOR_H - 0.2, 0.3),
		CFrame = front * CFrame.new(-DOOR_W / 2, DOOR_H / 2, -LOG_D / 2) * CFrame.Angles(0, math.rad(-80), 0) * CFrame.new((DOOR_W - 0.2) / 2, 0, 0),
		Color = Color3.fromRGB(122, 80, 48),
		Material = Enum.Material.WoodPlanks,
	})

	-- Ceiling with beams.
	Props.make("Ceiling", parent, {
		Size = Vector3.new(W + 2 * LOG_D, 0.4, D + 2 * LOG_D),
		CFrame = floorCf * CFrame.new(0, wallH + 0.2, 0),
		Color = LOG,
		Material = Enum.Material.WoodPlanks,
	})
	for _, x in { -W / 3, 0, W / 3 } do
		Props.make("Beam", parent, {
			Size = Vector3.new(1, 1, D),
			CFrame = floorCf * CFrame.new(x, wallH - 0.5, 0),
			Color = LOG_DARK,
			Material = Enum.Material.Wood,
		})
	end

	-- Gable roof (ridge along X) with overhangs, and gable-end triangles.
	local overhang = 2
	local run = halfD + LOG_D / 2 + overhang
	local slope = math.atan2(RISE, run)
	local slabLen = math.sqrt(run * run + RISE * RISE) + 0.6
	for _, dir in { 1, -1 } do
		Props.make("Roof", parent, {
			Size = Vector3.new(2 * halfW + LOG_D + 2 * overhang, 0.8, slabLen),
			CFrame = floorCf * CFrame.new(0, wallH + RISE / 2 + 0.4, dir * run / 2) * CFrame.Angles(dir * slope, 0, 0),
			Color = ROOF,
			Material = Enum.Material.WoodPlanks,
		})
	end
	for _, x in { -halfW, halfW } do
		for _, dir in { 1, -1 } do
			local wedge = Instance.new("WedgePart")
			wedge.Name = "Gable"
			wedge.Anchored = true
			wedge.Size = Vector3.new(LOG_D, RISE * (halfD / run), halfD)
			wedge.CFrame = floorCf * CFrame.new(x, wallH + wedge.Size.Y / 2, dir * halfD / 2) * CFrame.Angles(0, if dir > 0 then math.pi else 0, 0)
			wedge.Color = LOG
			wedge.Material = Enum.Material.WoodPlanks
			wedge.Parent = parent
		end
	end

	-- Stone chimney on the back wall, up through the roof.
	local chimneyTop = wallH + RISE + 3
	Props.make("Chimney", parent, {
		Size = Vector3.new(5, chimneyTop + FLOOR, 3),
		CFrame = cf * CFrame.new(0, (chimneyTop + FLOOR) / 2, -halfD - LOG_D / 2 - 1.5),
		Color = STONE,
		Material = Enum.Material.Cobblestone,
	})

	-- Covered porch: deck, posts, railings, a lean-to roof and steps.
	local porchDepth, porchW = 7, 22
	local deckZ = halfD + LOG_D / 2 + porchDepth / 2
	Props.make("Deck", parent, {
		Size = Vector3.new(porchW, FLOOR, porchDepth),
		CFrame = cf * CFrame.new(0, FLOOR / 2, deckZ),
		Color = FLOOR_WOOD,
		Material = Enum.Material.WoodPlanks,
	})
	local postH = 9
	for _, x in { -porchW / 2 + 0.6, porchW / 2 - 0.6 } do
		Props.make("Post", parent, {
			Size = Vector3.new(0.9, postH, 0.9),
			CFrame = cf * CFrame.new(x, FLOOR + postH / 2, deckZ + porchDepth / 2 - 0.6),
			Color = LOG_DARK,
			Material = Enum.Material.Wood,
		})
	end
	local porchRun = porchDepth + 1
	local porchDrop = 1.6
	Props.make("PorchRoof", parent, {
		Size = Vector3.new(porchW + 1.5, 0.5, math.sqrt(porchRun * porchRun + porchDrop * porchDrop)),
		CFrame = cf * CFrame.new(0, FLOOR + postH + porchDrop / 2 + 0.3, halfD + LOG_D / 2 + porchRun / 2) * CFrame.Angles(math.atan2(porchDrop, porchRun), 0, 0),
		Color = ROOF,
		Material = Enum.Material.WoodPlanks,
	})
	local stairW = 6
	local railY = FLOOR + 1.8
	local frontEdge = deckZ + porchDepth / 2 - 0.3
	for _, seg in { { -porchW / 2 + 0.6, -stairW / 2 }, { stairW / 2, porchW / 2 - 0.6 } } do
		local len = seg[2] - seg[1]
		Props.make("Rail", parent, {
			Size = Vector3.new(len, 0.3, 0.3),
			CFrame = cf * CFrame.new((seg[1] + seg[2]) / 2, railY, frontEdge),
			Color = LOG_DARK,
			Material = Enum.Material.Wood,
		})
		for k = 0, math.floor(len / 1.4) do
			Props.make("Baluster", parent, {
				Size = Vector3.new(0.2, 1.8, 0.2),
				CFrame = cf * CFrame.new(seg[1] + k * len / math.max(1, math.floor(len / 1.4)), FLOOR + 0.9, frontEdge),
				Color = LOG,
				Material = Enum.Material.Wood,
				Solid = false,
			})
		end
	end
	for k = 1, 3 do
		local h = FLOOR * (3 - k + 0.5) / 3.5
		Props.make("Step", parent, {
			Size = Vector3.new(stairW, h, 1.1),
			CFrame = cf * CFrame.new(0, h / 2, deckZ + porchDepth / 2 + (k - 0.5) * 1.1),
			Color = FLOOR_WOOD,
			Material = Enum.Material.WoodPlanks,
		})
	end

	-- Details by the door: barrels, a flower box, a lantern on the porch.
	for _, x in { -DOOR_W / 2 - 3, DOOR_W / 2 + 3 } do
		Props.make("Barrel", parent, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.4, 1.8, 1.8),
			CFrame = cf * CFrame.new(x, FLOOR + 1.2, halfD + LOG_D / 2 + 1.4) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(130, 84, 50),
			Material = Enum.Material.Wood,
		})
	end
	-- Flower beds on the ground either side of the steps (not on the deck,
	-- where they poked through the railing).
	for _, x in { -stairW / 2 - 8, stairW / 2 + 8 } do
		Props.planters(parent, cf * CFrame.new(x, 0, deckZ + porchDepth / 2 + 2.2), 0, 0)
	end
	lamp(parent, cf * CFrame.new(DOOR_W / 2 + 1.2, FLOOR + postH - 2.6, halfD + LOG_D / 2 + 1.2), 18)

	return {
		Entrance = cf * CFrame.new(0, 0, deckZ + porchDepth / 2 + 3.6),
		SignAt = cf * CFrame.new(0, FLOOR + postH - 1.6, deckZ + porchDepth / 2 - 0.3),
		Floor = floorCf * CFrame.new(0, 0.2, 0),
		Width = W,
		Depth = D,
		Height = wallH - 0.2,
		DoorX = 0,
		DoorHeight = DOOR_H,
		FrontOutside = halfD + LOG_D / 2,
	}
end

-- Furnishing ----------------------------------------------------------------------


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
	local sideZ = math.min(7.2, halfD - 4) -- clear of the side windows
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

	-- Mowers parked on the lawn beside the cabin (clear of porch and beds).
	ShopDisplay.Park(m, ground * CFrame.new(halfW + 5, 0, room.FrontOutside - 2), mowers, 3)

	-- Big sign hanging under the front edge of the porch roof, between the
	-- posts, facing the path: nothing in front of it.
	local sign = Props.make("ShopSign", m, {
		Size = Vector3.new(12, 2.4, 0.4),
		CFrame = room.SignAt,
		Color = Color3.fromRGB(110, 72, 42),
		Material = Enum.Material.WoodPlanks,
	})
	Props.label(sign, Enum.NormalId.Back, title:upper(), Color3.fromRGB(255, 196, 90))
	for _, x in { -4.5, 4.5 } do
		Props.make("SignChain", m, {
			Size = Vector3.new(0.12, 1.1, 0.12),
			CFrame = room.SignAt * CFrame.new(x, 1.75, 0),
			Color = Color3.fromRGB(40, 36, 32),
			Material = Enum.Material.Metal,
			Solid = false,
		})
	end
end

function ShopInterior.Build(parent: Instance, cf: CFrame, toolIds: { string }, title: string, keeper: string)
	local m = Props.model("ShopBuilding", parent)
	local room = logShell(m, cf)
	furnish(m, room, toolIds, title, keeper)
	m:SetAttribute("Entrance", room.Entrance.Position)
	return m
end

ShopInterior.Radius = 30

return ShopInterior
