--!strict
-- Local planting-bed previews. They follow the existing GrassArea contracts,
-- never replace baked world content, and never decide harvest/rewards.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tuning = require(Shared.Config.Progression)
local Zones = require(Shared.Config.Zones)
local Seeds = require(Shared.Config.Seeds)
local C = require(Shared.Config.Interface).Colors
local Layout = require(Shared.PlantingPlots)
local State = require(script.Parent:WaitForChild("ClientState"))
local Land = require(script.Parent:WaitForChild("LandState"))
local player = Players.LocalPlayer
local folder = Instance.new("Folder")
folder.Name = "PlantingPreviews"; folder.Parent = workspace
local beds = {}
local function part(parent, name, size, frame, color)
	local item = Instance.new("Part")
	item.Name = name; item.Anchored = true; item.CanCollide = false
	item.CanTouch = false; item.CanQuery = false
	item.Size = size; item.CFrame = frame; item.Color = color
	item.Material = Enum.Material.Wood; item.Parent = parent
	return item
end
local function build()
	local zones = workspace:FindFirstChild("Zones")
	if not zones then return end
	for _, zone in Zones.List do
		local region = zones:FindFirstChild(zone.Id)
		local area = Layout.LargestArea(region)
		if not area or not area:IsA("BasePart") or not Land.IsUnlocked(zone.Id) then continue end
		for slot = 1, Tuning.PlotsPerZone do
			local key = zone.Id .. ":" .. slot
			if beds[key] then continue end
			local position = Layout.Position(area, slot)
			local model = Instance.new("Model"); model.Name = key
			local size = Tuning.PlotSize
			local center = area.CFrame.Rotation + position
			local soil = part(model, "Bed", Vector3.new(size, Tuning.PlotRailHeight, size), center * CFrame.new(0, Tuning.PlotRailHeight / 2, 0), C.Wood)
			for _, axis in { -1, 1 } do
				part(model, "Rail", Vector3.new(size, Tuning.PlotRailHeight, 0.4), center * CFrame.new(0, Tuning.PlotRailHeight / 2, axis * size / 2), C.Wood)
				part(model, "Rail", Vector3.new(0.4, Tuning.PlotRailHeight, size), center * CFrame.new(axis * size / 2, Tuning.PlotRailHeight / 2, 0), C.Wood)
			end
			local sign = Instance.new("BillboardGui")
			sign.Size = UDim2.fromOffset(160, 46); sign.StudsOffset = Vector3.new(0, 2, 0)
			sign.MaxDistance = 45; sign.Adornee = soil; sign.Parent = soil
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1); label.BackgroundColor3 = C.Cream
			label.TextColor3 = C.Ink; label.TextWrapped = true; label.Font = Enum.Font.GothamBold
			label.TextSize = 14; label.Parent = sign
			model.Parent = folder
			beds[key] = { Model = model, Soil = soil, Label = label, ZoneId = zone.Id }
		end
	end
end
local function refresh()
	build()
	local profile = State.Get()
	for key, bed in beds do
		local open = Land.IsUnlocked(bed.ZoneId)
		bed.Model.Parent = if open then folder else nil
		local plot = profile and profile.Plots[key]
		if plot then
			local seed = Seeds.ById[plot.SeedId]
			local ready = os.time() >= plot.ReadyAt
			bed.Soil.Color = if ready then C.Gold else C.Green
			bed.Label.Text = (seed and seed.DisplayName or "Seed") .. (if ready then "\nReady — cut to harvest" else "\nGrowing...")
		else
			bed.Soil.Color = C.Wood
			bed.Label.Text = if workspace:GetAttribute("LandHostUserId") == player.UserId then "Plant a seed\nGarden in Crew menu" else "Owner's planting bed"
		end
	end
end
State.Changed:Connect(refresh)
Land.Changed:Connect(refresh)
task.spawn(function() while true do refresh(); task.wait(2) end end)
