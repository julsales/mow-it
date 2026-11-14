--!strict
-- Hay bales on this client: the bale model (art/yard bale, painted; golden
-- ones shine), the little moves they make (slide, hop, drop) and the stack
-- on the pallet. Bales are local visuals of profile.Hay.Bales; the server
-- owns which bales exist and what they are worth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.HayYard)
local YardArt = require(Shared.YardArt)

local HayBales = {}

local SIZE = Config.Models.bale.Size
local HALF = Vector3.new(0, Config.Stack.BaleHeight / 2, 0)

export type Entry = { Id: number, Model: Model, Hit: BasePart, Golden: boolean, Column: number, Busy: number }

-- Yields; calls step(0..1) every frame for `duration` seconds.
function HayBales.Animate(duration: number, step: (number) -> ())
	local t = 0
	while t < duration do
		t += RunService.RenderStepped:Wait()
		step(math.min(t / duration, 1))
	end
end

local function easeOut(a: number): number
	return 1 - (1 - a) ^ 3
end

-- A bale whose pivot is its centre.
function HayBales.Make(golden: boolean, parent: Instance): (Model, BasePart)
	local model = YardArt.Build("bale")
	if not model then -- art not loaded: a plain block still works
		model = Instance.new("Model")
		local block = Instance.new("Part")
		block.Name = "Hay"
		block.Size = Vector3.new(2.4, 1.5, 1.5)
		block.CFrame = CFrame.new(HALF)
		block.Color = Config.Paint.Hay.Color
		block.Material = Enum.Material.SmoothPlastic
		block.Anchored = true
		block.CanCollide = false
		block.CanQuery = false
		block.Parent = model
	end
	local bale = model :: Model
	bale.Name = "Bale"
	bale.WorldPivot = CFrame.new(HALF)
	-- What the mouse hits (the meshes themselves ignore it).
	local hit = Instance.new("Part")
	hit.Name = "Hit"
	hit.Size = Vector3.new(SIZE.X - 0.3, SIZE.Y, SIZE.Z)
	hit.CFrame = CFrame.new(HALF)
	hit.Transparency = 1
	hit.Anchored = true
	hit.CanCollide = false
	hit.CanTouch = false
	hit.CastShadow = false
	hit.Parent = bale
	if golden then
		local look = Config.GoldenBale
		for _, d in bale:GetChildren() do
			if d:IsA("BasePart") and d ~= hit then
				d.Color = (look :: any)[d.Name] or look.Hay
				d.Material = look.Material
				d.Reflectance = look.Reflectance
			end
		end
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "Sparkles"
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 240, 170))
		sparkles.LightEmission = 0.8
		sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 0) })
		sparkles.Lifetime = NumberRange.new(0.6, 1.1)
		sparkles.Rate = 7
		sparkles.Speed = NumberRange.new(0.6, 1.6)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Parent = hit
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 214, 110)
		glow.Range = 7
		glow.Brightness = 0.8
		glow.Parent = hit
	end
	bale.Parent = parent
	return bale, hit
end

-- Straight move with a soft stop.
function HayBales.Slide(model: Model, from: CFrame, to: CFrame, duration: number)
	HayBales.Animate(duration, function(a)
		model:PivotTo(from:Lerp(to, easeOut(a)))
	end)
end

-- A hop through the air: an arc `height` studs above the higher end, with
-- `turns` tumbles around the bale's long axis, and a small bounce.
function HayBales.Hop(model: Model, from: CFrame, to: CFrame, duration: number, height: number, turns: number?)
	local base = math.max(from.Y, to.Y) + height
	local spin = (turns or 0) * 2 * math.pi
	HayBales.Animate(duration, function(a)
		local flat = from:Lerp(to, a)
		-- parabola through from.Y, the peak and to.Y
		local up = (1 - a) * from.Y + a * to.Y + 4 * a * (1 - a) * (base - (from.Y + to.Y) / 2)
		model:PivotTo(CFrame.new(flat.X, up, flat.Z) * flat.Rotation * CFrame.Angles(spin * a, 0, 0))
	end)
	HayBales.Bounce(model, to)
end

-- Squash-free landing: a quick dip and settle.
function HayBales.Bounce(model: Model, at: CFrame)
	HayBales.Animate(0.16, function(a)
		model:PivotTo(at * CFrame.new(0, 0.22 * math.sin(a * math.pi) * (1 - a), 0) * CFrame.Angles(0, 0, 0.05 * math.sin(a * math.pi * 2) * (1 - a)))
	end)
	model:PivotTo(at)
end

-- Grows from nothing (a bale squeezing out of the chamber, or onto the counter).
function HayBales.Pop(model: Model, duration: number)
	HayBales.Animate(duration, function(a)
		model:ScaleTo(math.max(0.05, easeOut(a) * (1 + 0.15 * math.sin(a * math.pi))))
	end)
	model:ScaleTo(1)
end

function HayBales.Shrink(model: Model, duration: number)
	HayBales.Animate(duration, function(a)
		model:ScaleTo(math.max(0.05, 1 - a))
	end)
end

-- The stack ---------------------------------------------------------------------
-- Bales stand in columns on the pallet; a new bale goes on the lowest
-- column, and when one is sold the bales above it drop down.
local Stack = {}
Stack.__index = Stack
HayBales.Stack = Stack

export type StackT = typeof(setmetatable({} :: { Pallet: Model, Columns: { { Entry } } }, Stack))

function Stack.new(pallet: Model): StackT
	local columns = {}
	for i = 1, #Config.Stack.Columns do
		columns[i] = {}
	end
	return setmetatable({ Pallet = pallet, Columns = columns }, Stack)
end

function Stack.SlotCFrame(self: StackT, entry: Entry, layer: number): CFrame
	local s = Config.Stack
	-- every bale sits a little crooked, always the same way (by its id)
	local yaw = math.rad(((entry.Id * 37) % 9) - 4)
	local at = s.Columns[entry.Column] + Vector3.new(0, s.Top + (layer - 0.5) * s.BaleHeight, 0)
	return self.Pallet:GetPivot() * CFrame.new(at) * CFrame.Angles(0, yaw, 0)
end

function Stack.LayerOf(self: StackT, entry: Entry): number
	return table.find(self.Columns[entry.Column], entry) or 1
end

-- Reserves a slot for the bale; returns where it will stand.
function Stack.Add(self: StackT, entry: Entry): CFrame
	local best = 1
	for i, column in self.Columns do
		if #column < #self.Columns[best] then
			best = i
		end
	end
	entry.Column = best
	table.insert(self.Columns[best], entry)
	return self:SlotCFrame(entry, #self.Columns[best])
end

-- Takes the bale off the stack; the bales above it drop into place.
function Stack.Remove(self: StackT, entry: Entry)
	local column = self.Columns[entry.Column]
	local layer = table.find(column, entry)
	if not layer then
		return
	end
	table.remove(column, layer)
	for i = layer, #column do
		local above = column[i]
		task.spawn(function()
			while above.Busy > 0 do
				task.wait()
			end
			-- it may have been sold or moved again meanwhile
			if table.find(column, above) then
				above.Busy += 1
				local to = self:SlotCFrame(above, table.find(column, above) :: number)
				local from = above.Model:GetPivot()
				HayBales.Animate(0.16, function(a)
					above.Model:PivotTo(from:Lerp(to, a * a))
				end)
				HayBales.Bounce(above.Model, to)
				above.Busy -= 1
			end
		end)
	end
end

return HayBales
