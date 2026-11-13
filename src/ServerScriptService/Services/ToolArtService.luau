--!strict
-- Loads the low-poly tool art (Config/ToolArt.Models, uploaded from
-- art/tools/) with InsertService and keeps one clean template per base
-- model in ReplicatedStorage/ToolArt, where ToolModels finds it on server
-- and client. Runs before the map builds the shop displays; a model that
-- isn't uploaded (AssetId 0) or fails to load just keeps the Part look.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToolArt = require(ReplicatedStorage:WaitForChild("Shared").Config.ToolArt)

local ToolArtService = {}

local LOAD_TIMEOUT = 20 -- seconds for all models together

-- The uploaded asset's Model, with every code instance removed and every
-- part made a passive, anchored-off template piece.
local function clean(container: Instance, name: string): Model?
	local found: Model? = nil
	if container:IsA("Model") and container:FindFirstChildWhichIsA("BasePart", true) then
		found = container
	end
	local inner = container:FindFirstChildWhichIsA("Model")
	if inner then
		found = inner -- LoadAsset wraps the asset in an extra Model
	end
	if not found then
		return nil
	end
	for _, d in found:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
			d:Destroy() -- assets never bring code (docs/ASSETS.md)
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	found.Name = name
	return found
end

-- Loads every uploaded model; returns when all are done or timed out.
function ToolArtService.Init()
	local folder = ReplicatedStorage:FindFirstChild("ToolArt") or Instance.new("Folder")
	folder.Name = "ToolArt"
	folder.Parent = ReplicatedStorage
	local pending = 0
	for name, def in ToolArt.Models do
		if def.AssetId > 0 and not folder:FindFirstChild(name) then
			pending += 1
			task.spawn(function()
				local ok, result = pcall(InsertService.LoadAsset, InsertService, def.AssetId)
				local model = if ok then clean(result, name) else nil
				if model then
					model.Parent = folder
				else
					warn(`[ToolArt] {name} ({def.AssetId}) did not load: {if ok then "no parts" else result}`)
				end
				pending -= 1
			end)
		end
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < LOAD_TIMEOUT do
		task.wait(0.1)
	end
end

return ToolArtService
