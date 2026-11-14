--!strict
-- The customers who buy hay at the silo, on this client only: a person
-- walks in from the yard's CustomerSpawn marker, waits at the counter while
-- the bales come out of the serving hatch, picks them up and carries them
-- away. The server decides when a customer comes and pays the tip
-- (HayService); this only shows it.
--
-- People are clones of ReplicatedStorage/YardArt/Customers (default R15
-- bodies). They are moved along the route by hand (anchored root, default
-- walk animation), so they never get stuck or push the player.

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config.HayYard)
local Bales = require(script.Parent:WaitForChild("HayBales"))

local HayCustomers = {}

local CARRY = CFrame.new(0, 0.1, -1.35) -- a bale in the arms, relative to the root
local ARMS_UP = math.rad(78)

local folder = Instance.new("Folder")
folder.Name = "HayCustomers"
folder.Parent = Workspace

local waiting = 0 -- people at the counter right now (they stand side by side)
local nextLook = 0

local function template(): Model?
	local art = ReplicatedStorage:FindFirstChild("YardArt")
	local people = art and art:FindFirstChild("Customers")
	local list = if people then people:GetChildren() else {}
	if #list == 0 then
		return nil
	end
	nextLook = nextLook % #list + 1
	local picked = list[nextLook]
	return if picked:IsA("Model") then picked else nil
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

-- The ground under a point (terrain, decks, paths), never people.
local function groundAt(point: Vector3): Vector3
	local ignore: { Instance } = { folder }
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	rayParams.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(point + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), rayParams)
	return if hit then hit.Position else point
end

local function route(from: Vector3, to: Vector3): { Vector3 }
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = false })
	local ok = pcall(function()
		path:ComputeAsync(from, to)
	end)
	local points = { from }
	if ok and path.Status == Enum.PathStatus.Success then
		for _, waypoint in path:GetWaypoints() do
			table.insert(points, waypoint.Position)
		end
	end
	table.insert(points, to)
	return points
end

local function length(points: { Vector3 }): number
	local total = 0
	for i = 2, #points do
		total += ((points[i] - points[i - 1]) * Vector3.new(1, 0, 1)).Magnitude
	end
	return total
end

type Person = { Model: Model, Root: BasePart, Height: number, Walk: AnimationTrack?, Idle: AnimationTrack?, Carried: { Model } }

local function track(animator: Animator, id: string): AnimationTrack?
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, result = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	return if ok then result else nil
end

local function spawnPerson(at: Vector3, facing: Vector3): Person?
	local source = template()
	if not source then
		return nil
	end
	local model = source:Clone()
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		model:Destroy()
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local person: Person = { Model = model, Root = root, Height = humanoid.HipHeight + root.Size.Y / 2, Walk = nil, Idle = nil, Carried = {} }
	root.Anchored = true
	root.CFrame = CFrame.lookAt(at + Vector3.new(0, person.Height, 0), at + facing + Vector3.new(0, person.Height, 0))
	model.Parent = folder
	person.Walk = track(animator, Config.Animations.Walk)
	person.Idle = track(animator, Config.Animations.Idle)
	return person
end

local function place(person: Person, at: Vector3, look: Vector3)
	local feet = groundAt(at)
	local eye = Vector3.new(feet.X, feet.Y + person.Height, feet.Z)
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 1e-3 then
		-- turn smoothly toward where we are going
		local goal = CFrame.lookAt(eye, eye + flat)
		person.Root.CFrame = CFrame.new(eye) * person.Root.CFrame.Rotation:Lerp(goal.Rotation, 0.2)
	else
		person.Root.CFrame = CFrame.new(eye) * person.Root.CFrame.Rotation
	end
	for i, bale in person.Carried do
		bale:PivotTo(person.Root.CFrame * CARRY * CFrame.new(0, (i - 1) * Config.Stack.BaleHeight, 0))
	end
end

local function walk(person: Person, points: { Vector3 }, speed: number)
	if person.Idle then
		person.Idle:Stop(0.2)
	end
	if person.Walk then
		person.Walk:Play(0.2)
		person.Walk:AdjustSpeed(speed / 12)
	end
	for i = 2, #points do
		local from, to = points[i - 1], points[i]
		local distance = ((to - from) * Vector3.new(1, 0, 1)).Magnitude
		local done = 0
		while done < distance do
			done += RunService.RenderStepped:Wait() * speed
			place(person, from:Lerp(to, math.min(done / distance, 1)), to - from)
		end
	end
	if person.Walk then
		person.Walk:Stop(0.2)
	end
	if person.Idle then
		person.Idle:Play(0.2)
	end
end

-- Arms forward to hold a bale: the shoulders turn, the animations keep
-- playing on top.
local function raiseArms(person: Person)
	for _, name in { "LeftUpperArm", "RightUpperArm" } do
		local arm = person.Model:FindFirstChild(name)
		local shoulder = arm and arm:FindFirstChildWhichIsA("Motor6D")
		if shoulder then
			shoulder.C0 *= CFrame.Angles(ARMS_UP, 0, 0)
		end
	end
end

local function fadeOut(person: Person)
	local parts = {}
	for _, d in person.Model:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			table.insert(parts, d)
		end
	end
	for _, bale in person.Carried do
		for _, d in bale:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "Hit" then
				table.insert(parts, d)
			end
		end
	end
	Bales.Animate(0.35, function(a)
		for _, d in parts do
			(d :: any).Transparency = a
		end
	end)
	for _, bale in person.Carried do
		bale:Destroy()
	end
	person.Model:Destroy()
end

-- One customer's whole visit. `silo` is the yard's Silo model, `spawnAt`
-- the CustomerSpawn marker, `walkSeconds` how long the way in should take.
-- `served` runs when the customer has the bales in hand. Yields.
function HayCustomers.Visit(silo: Model, spawnAt: Vector3, bales: number, walkSeconds: number, served: () -> ())
	local markers = Config.Pieces.Silo.Markers
	local pivot = silo:GetPivot()
	local slot = waiting
	waiting += 1
	local side = ((slot % 3) - 1) * 2.4 -- stand beside whoever is already there
	local stand = (pivot * CFrame.new(markers.Customer + Vector3.new(side, 0, (slot % 2) * 1.2))).Position
	local from = groundAt(spawnAt)
	local points = route(from, groundAt(stand))
	local person = spawnPerson(from, stand - from)
	if not person then
		waiting -= 1
		served()
		return
	end
	local speed = math.clamp(length(points) / math.max(walkSeconds, 0.1), Config.CustomerSpeed.Min, Config.CustomerSpeed.Max)
	walk(person, points, speed)
	-- face the counter
	local counter = (pivot * CFrame.new(markers.Counter + Vector3.new(side, 0, 0))).Position
	Bales.Animate(0.2, function()
		place(person, stand, counter - stand)
	end)
	-- the bales come out of the hatch onto the counter, one on the other
	local window = pivot * CFrame.new(markers.Window + Vector3.new(side * 0.3, 0, 0))
	local onCounter = {}
	for i = 1, bales do
		local bale = Bales.Make(false, folder)
		local rest = pivot * CFrame.new(markers.Counter + Vector3.new(side * 0.3, (i - 0.5) * Config.Stack.BaleHeight, 0))
		bale:ScaleTo(0.05)
		bale:PivotTo(window)
		task.spawn(Bales.Pop, bale, 0.25)
		Bales.Slide(bale, window, rest, 0.3)
		table.insert(onCounter, bale)
	end
	task.wait(0.25)
	raiseArms(person)
	for _, bale in onCounter do
		table.insert(person.Carried, bale)
	end
	place(person, stand, counter - stand)
	served()
	waiting -= 1
	task.wait(0.35)
	-- and back the way they came
	local back = table.create(#points)
	for i = #points, 1, -1 do
		table.insert(back, points[i])
	end
	walk(person, back, speed)
	fadeOut(person)
end

return HayCustomers
