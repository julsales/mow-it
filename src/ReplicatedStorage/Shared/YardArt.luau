--!strict
-- The hay yard's Blender models (art/yard/, loaded by ToolArtService into
-- ReplicatedStorage/YardArt): one painted copy, standing at the world
-- origin exactly as authored. The server builds the yard from them
-- (Map/HayYard); clients make bales from the same template.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config.HayYard)
local ToolArt = require(script.Parent.Config.ToolArt)
local ArtModels = require(script.Parent.ArtModels)

local YardArt = {}

function YardArt.Has(modelName: string): boolean
	local folder = ReplicatedStorage:FindFirstChild("YardArt")
	return folder ~= nil and folder:FindFirstChild(modelName) ~= nil
end

-- Mesh pieces are named after their colour group; moving pieces carry a
-- "Rig" attribute (HayRigs). Everything is anchored and walk-through.
function YardArt.Build(modelName: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("YardArt")
	local template = folder and folder:FindFirstChild(modelName)
	local def = Config.Models[modelName]
	if not template or not template:IsA("Model") or not def then
		return nil
	end
	local copy = template:Clone()
	ArtModels.Restore(copy, def)
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			local group, _, rigName = ArtModels.Split(d.Name)
			d.Name = group
			if rigName then
				d:SetAttribute("Rig", rigName)
			end
			local paint = Config.Paint[group] or ToolArt.Pieces[group]
			if paint then
				ArtModels.Paint(d, paint)
			end
			ArtModels.Strip(d)
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	copy.WorldPivot = CFrame.identity
	for rigName, pivot in def.Pivots or {} do
		copy:SetAttribute("Pivot_" .. rigName, pivot)
	end
	return copy
end

return YardArt
