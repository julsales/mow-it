--!strict
-- Finding personal bases in the place (contract, docs/EDITING.md):
--   Workspace/Bases/<any name> (Model)   one per base, built by Map/Bases
--     attributes OwnerUserId (0 = vacant) and OwnerName, set by BaseService
--     HayYard (Model), PlayerBase (Model, the cabin), BaseSpawn
--     (SpawnLocation), Jetty (Model), OwnerSign (Part)
-- Server and client both ask this module, never positions or slot names.

local Workspace = game:GetService("Workspace")

local Bases = {}

Bases.FolderName = "Bases"
Bases.OwnerAttribute = "OwnerUserId"
Bases.OwnerNameAttribute = "OwnerName"

function Bases.Folder(): Instance?
	return Workspace:FindFirstChild(Bases.FolderName)
end

function Bases.All(): { Model }
	local list = {}
	local folder = Bases.Folder()
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") then
				table.insert(list, child)
			end
		end
		table.sort(list, function(a, b)
			return a.Name < b.Name
		end)
	end
	return list
end

-- The base a player owns in this server, or nil.
function Bases.Of(userId: number): Model?
	for _, base in Bases.All() do
		if base:GetAttribute(Bases.OwnerAttribute) == userId then
			return base
		end
	end
	return nil
end

-- The base an instance belongs to (itself or an ancestor), or nil.
function Bases.Containing(instance: Instance): Model?
	local folder = Bases.Folder()
	local node: Instance? = instance
	while node and folder and node.Parent ~= folder do
		node = node.Parent
	end
	return if folder and node and node:IsA("Model") then node else nil
end

-- True when the instance is inside a base that is NOT this player's
-- (someone else's, or vacant): its pads and machines don't work for them.
function Bases.IsForeign(instance: Instance, userId: number): boolean
	local base = Bases.Containing(instance)
	return base ~= nil and base:GetAttribute(Bases.OwnerAttribute) ~= userId
end

-- A named piece of a player's base ("HayYard", "BaseSpawn", "Jetty", ...).
function Bases.Piece(userId: number, name: string): Instance?
	local base = Bases.Of(userId)
	return base and base:FindFirstChild(name)
end

return Bases
