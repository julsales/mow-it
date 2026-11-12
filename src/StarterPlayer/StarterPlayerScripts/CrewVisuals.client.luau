--!strict
-- Local companion previews from the owned roster; all harvesting stays server-side.
-- shortcut: one project-authored critter silhouette, replace with audited species
-- models when the Crew asset phase ships (docs/ASSETS.md).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tuning = require(Shared.Config.Progression)
local Rules = require(Shared.ProgressionRules)
local C = require(Shared.Config.Interface).Colors
local State = require(script.Parent:WaitForChild("ClientState"))
local player = Players.LocalPlayer
local models = {}
local profile = State.Get()
local function sphere(parent, name, size, offset, color)
	local part = Instance.new("Part")
	part.Name = name; part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * size; part.CFrame = CFrame.new(offset)
	part.Color = color; part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true; part.CanCollide = false; part.CanTouch = false; part.CanQuery = false
	part.Parent = parent
	return part
end
local function refresh(data)
	profile = data
	local keep = {}
	for _, uid in data.EquippedCrew do
		keep[uid] = true
		local entry = data.Crew[uid]
		local def = entry and Rules.CrewDef(entry.Id)
		if not def then continue end
		local existing = models[uid]
		if existing and existing:GetAttribute("Evolution") == entry.Evolution then continue end
		if existing then existing:Destroy() end
		local rarity = table.find(require(Shared.Config.Crew).Rarities, def.Rarity) or 1
		local size = 1.1 + rarity * 0.13 + entry.Evolution * 0.2
		local model = Instance.new("Model"); model.Name = "Crew_" .. uid
		local body = sphere(model, "Body", size, Vector3.new(0, size / 2, 0), if entry.Evolution > 0 then C.Gold else C.Green)
		model.PrimaryPart = body
		for _, side in { -1, 1 } do
			sphere(model, "Eye", size * 0.18, Vector3.new(side * size * 0.23, size * 0.75, -size * 0.4), C.Cream)
			sphere(model, "Pupil", size * 0.09, Vector3.new(side * size * 0.23, size * 0.75, -size * 0.48), C.Ink)
		end
		local label = Instance.new("BillboardGui")
		label.Size = UDim2.fromOffset(140, 40); label.StudsOffset = Vector3.new(0, size, 0)
		label.MaxDistance = 35; label.Adornee = body; label.Parent = body
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1); text.BackgroundTransparency = 1
		text.Text = def.DisplayName; text.TextColor3 = C.Cream; text.TextStrokeTransparency = 0
		text.TextStrokeColor3 = C.Ink; text.TextSize = 14; text.TextWrapped = true
		text.Font = Enum.Font.GothamBold; text.Parent = label
		model:SetAttribute("Evolution", entry.Evolution)
		model.Parent = workspace; models[uid] = model
	end
	for uid, model in models do if not keep[uid] then model:Destroy(); models[uid] = nil end end
end
State.Changed:Connect(refresh)
if profile then refresh(profile) end
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.1 or not profile then return end
	elapsed = 0
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { character }
	for _, model in models do table.insert(ignore, model) end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	for index, uid in profile.EquippedCrew do
		local entry = profile.Crew[uid]
		local model = models[uid]
		if not entry or not model then continue end
		local target = root.Position + Vector3.new(math.cos(index * 2) * Tuning.CrewFollowSpacing, 0, math.sin(index * 2) * Tuning.CrewFollowSpacing)
		if entry.Mode == "Station" and entry.Position then target = Vector3.new(table.unpack(entry.Position)) end
		local hit = workspace:Raycast(target + Vector3.new(0, 8, 0), Vector3.new(0, -50, 0), params)
		if hit then target = hit.Position + Vector3.new(0, (model.PrimaryPart :: BasePart).Size.Y / 2, 0) end
		model:PivotTo(CFrame.new(target))
	end
end)
