--!strict
-- Builds the hay yard (Shared/Config/HayYard.luau): the baler, the pallet
-- the bales are stacked on and the silo with its elevator and counter,
-- from the Blender models in ReplicatedStorage/YardArt.
--
-- Contract (docs/EDITING.md): one Model "HayYard" inside the home island,
-- holding the Models "Baler", "BaleStack" and "Silo" (drag each one
-- freely: the animations read where they stand), the baler's invisible
-- "SellPad" (where grass is handed in) and the invisible "CustomerSpawn"
-- marker customers walk in from.
--
-- Frame `cf`: origin on the ground, +Z = the front (where players stand).

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.HayYard)
local Zones = require(Shared.Config.Zones)
local YardArt = require(Shared.YardArt)
local Props = require(script.Parent.Props)

local HayYard = {}

HayYard.Radius = Config.Radius

local SIGN_TEXT = Color3.fromRGB(90, 60, 0)
local CUSTOMER_GROUP = "YardCustomers"

local function hidden(name: string, parent: Instance, cf: CFrame, size: Vector3, solid: boolean): Part
	local part = Props.make(name, parent, { Size = size, CFrame = cf, Color = Props.Colors.White, Transparency = 1, Solid = solid })
	part.CastShadow = false
	return part
end

local function buildPiece(yard: Model, name: string, def: Config.PieceDef, cf: CFrame): Model?
	local model = YardArt.Build(def.Model)
	if not model then
		return nil
	end
	model.Name = name
	for _, box in def.Colliders do
		local at = CFrame.new(box.Center) * CFrame.Angles(0, 0, math.rad(box.Tilt or 0))
		local wall = hidden("Collider", model, at, box.Size, true)
		if box.Round then -- upright cylinder
			wall.Shape = Enum.PartType.Cylinder
			wall.Size = Vector3.new(box.Size.Y, box.Size.X, box.Size.Z)
			wall.CFrame = at * CFrame.Angles(0, 0, math.rad(90))
		end
	end
	for _, sign in def.Signs do
		local board = Props.make(sign.Name, model, { Size = sign.Size, CFrame = CFrame.new(sign.Center), Color = Props.Colors.White, Solid = false })
		Props.label(board, Enum.NormalId.Back, sign.Text, SIGN_TEXT)
		if sign.Rig then
			board:SetAttribute("Rig", sign.Rig)
		end
	end
	model:PivotTo(cf)
	model.Parent = yard
	return model
end

-- Packed dirt under the machines, so they stand on a yard instead of the
-- lawn: thin parts like the paths (two crossed slabs and four round
-- corners per pad, a hair apart in height so overlaps never flicker).
local function buildGround(yard: Model, cf: CFrame)
	local ground = Props.model("Ground", yard)
	local spec = Config.Ground
	local r = spec.Corner
	local function slab(index: number, center: Vector3, size: Vector3, round: boolean)
		local lift = 0.05 + (index % 4) * 0.012
		local part = Props.make("Dirt", ground, {
			Shape = if round then Enum.PartType.Cylinder else nil,
			Size = if round then Vector3.new(0.2, size.X, size.X) else Vector3.new(size.X, 0.2, size.Z),
			CFrame = cf * CFrame.new(center.X, lift, center.Z) * (if round then CFrame.Angles(0, 0, math.rad(90)) else CFrame.identity),
			Color = spec.Color,
			Material = Enum.Material.Ground,
		})
		part.CanQuery = false
	end
	for i, pad in spec.Pads do
		local w, d = pad.Size.X, pad.Size.Z
		slab(i, pad.Center, Vector3.new(w - 2 * r, 0, d), false)
		slab(i + 1, pad.Center, Vector3.new(w, 0, d - 2 * r), false)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				slab(i + 2, pad.Center + Vector3.new(sx * (w / 2 - r), 0, sz * (d / 2 - r)), Vector3.new(2 * r, 0, 2 * r), true)
			end
		end
	end
	ground.WorldPivot = cf
end

-- The yard, or nil when its art isn't loaded (ids missing or offline).
function HayYard.Build(parent: Instance, cf: CFrame): Model?
	for _, def in Config.Pieces do
		if not YardArt.Has(def.Model) then
			warn(`[MowIt][HayYard] Model "{def.Model}" is not loaded; the yard was not built.`)
			return nil
		end
	end
	local yard = Props.model("HayYard", parent)
	yard.WorldPivot = cf
	buildGround(yard, cf)
	local pieces: { [string]: Model } = {}
	for name, def in Config.Pieces do
		pieces[name] = buildPiece(yard, name, def, cf * def.Offset) :: Model
	end
	-- Contract part "SellPad": standing in it loads your grass into the baler.
	local zone = Config.LoadZone
	local host = pieces[zone.Piece]
	hidden("SellPad", host, host:GetPivot() * CFrame.new(zone.Center), zone.Size, false)
	hidden("CustomerSpawn", yard, cf * CFrame.new(Config.CustomerSpawn + Vector3.new(0, 0.5, 0)), Vector3.new(2, 1, 2), false)
	return yard
end

function HayYard.Find(): Model?
	local zones = Workspace:FindFirstChild("Zones")
	local yard = zones and zones:FindFirstChild("HayYard", true)
	return if yard and yard:IsA("Model") then yard else nil
end

-- A place baked before the hay yard existed: the yard takes the place of
-- the home island's old sell station (for this session; bake it in Studio
-- to keep it, docs/EDITING.md).
function HayYard.EnsureBuilt()
	if HayYard.Find() then
		return
	end
	local zones = Workspace:FindFirstChild("Zones")
	local home = zones and zones:FindFirstChild(Zones.List[1].Id)
	local station = home and home:FindFirstChild("SellStation")
	if not home or not station or not station:IsA("Model") then
		return
	end
	if HayYard.Build(home, station:GetPivot()) then
		station:Destroy()
	end
end

-- The people who shop at the silo: one template each in
-- ReplicatedStorage/YardArt/Customers; clients clone and walk them.
function HayYard.BuildCustomers()
	local art = ReplicatedStorage:FindFirstChild("YardArt") or Instance.new("Folder")
	art.Name = "YardArt"
	art.Parent = ReplicatedStorage
	if art:FindFirstChild("Customers") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Customers"
	folder.Parent = art
	-- Customers never push anyone around.
	PhysicsService:RegisterCollisionGroup(CUSTOMER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(CUSTOMER_GROUP, "Default", false)
	for i, look in Config.Customers do
		task.spawn(function()
			local person = Props.person(look)
			if person then
				person.Name = "Customer" .. i
				for _, d in person:GetDescendants() do
					if d:IsA("BasePart") then
						d.CanCollide = false
						d.CollisionGroup = CUSTOMER_GROUP
						d.CanQuery = false
						d.CanTouch = false
					end
				end
				person.Parent = folder
			end
		end)
	end
end

return HayYard
