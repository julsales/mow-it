--!strict
-- One owner for all local destination trails. Full storage takes priority over
-- quest navigation. Path computations may yield; revisions discard stale work.
local Players = game:GetService("Players")
local Pathfinding = game:GetService("PathfindingService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config.Quests).Route
local Guide = {}
local requests = {}
local revision = 0
local previousKey, previousTarget, previousRoot, previousPosition = nil, nil, nil, nil
local lastBuild = -math.huge
local folder = Instance.new("Folder")
folder.Name = "WorldGuide"
folder.Parent = workspace
local status = ""
local function erase()
	folder:ClearAllChildren()
end
function Guide.Set(key: string, target: BasePart, priority: number, usePath: boolean)
	local old = requests[key]
	if old and old.Target == target and old.Priority == priority and old.Path == usePath then return end
	requests[key] = { Target = target, Priority = priority, Path = usePath }
	revision += 1
end
function Guide.Clear(key: string)
	if not requests[key] then return end
	requests[key] = nil; revision += 1
	-- Do not leave the old trail visible while the replacement path yields.
	erase()
end
function Guide.Status(): string return status end
local function draw(points: { Vector3 })
	erase()
	local previous: Attachment? = nil
	for index, position in points do
		if index > Config.MaxPoints then break end
		local part = Instance.new("Part")
		part.Name = "Waypoint"
		part.Size = Vector3.one * 0.1
		part.Anchored = true; part.Transparency = 1
		part.CanCollide = false; part.CanTouch = false; part.CanQuery = false
		part.Position = position
		local attachment = Instance.new("Attachment")
		attachment.Parent = part
		if previous then
			local beam = Instance.new("Beam")
			beam.Attachment0 = previous; beam.Attachment1 = attachment
			beam.Color = ColorSequence.new(Config.Color)
			beam.Width0 = Config.Width; beam.Width1 = Config.Width
			beam.Transparency = NumberSequence.new(0.12)
			beam.FaceCamera = true; beam.LightEmission = 0.7
			beam.Parent = part
		end
		part.Parent = folder
		previous = attachment
	end
end
task.spawn(function()
	while folder.Parent do
		task.wait(0.25)
		local key, selected = nil, nil
		for name, request in requests do
			if request.Target.Parent and (not selected or request.Priority > selected.Priority) then key = name; selected = request end
		end
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or not selected then
			erase(); previousKey = nil; status = ""; continue
		end
		local destination = selected.Target.Position
		if (root.Position - destination).Magnitude < Config.ArrivalDistance then
			erase(); previousKey = nil; status = "You've arrived · talk to the NPC"; continue
		end
		local moved = not previousPosition or (root.Position - previousPosition).Magnitude >= Config.MovementThreshold
		if key == previousKey and selected.Target == previousTarget and root == previousRoot
			and os.clock() - lastBuild < Config.RefreshSeconds and not moved then continue end
		previousKey = key; previousTarget = selected.Target; previousRoot = root
		previousPosition = root.Position; lastBuild = os.clock()
		local token = revision
		local points = { root.Position - Vector3.new(0, 2.5, 0), destination + Vector3.new(0, 0.4, 0) }
		if selected.Path then
			local route = Pathfinding:CreatePath({ AgentRadius = Config.AgentRadius, AgentHeight = Config.AgentHeight,
				AgentCanJump = true, WaypointSpacing = Config.Spacing })
			local ok = pcall(function() route:ComputeAsync(root.Position, destination + Vector3.new(0, 2, 0)) end)
			if token ~= revision or not root.Parent or not selected.Target.Parent then route:Destroy(); continue end
			if ok and route.Status == Enum.PathStatus.Success then
				points = {}
				for _, waypoint in route:GetWaypoints() do table.insert(points, waypoint.Position + Vector3.new(0, 0.2, 0)) end
				status = "Follow the golden trail"
			else
				-- Never draw a straight route through a wall when navigation fails.
				points = {}; status = "Head toward the NPC marker · trail unavailable here"
			end
			route:Destroy()
		end
		if token == revision then draw(points) end
	end
end)
return Guide
