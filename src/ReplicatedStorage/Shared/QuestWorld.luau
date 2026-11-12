--!strict
-- Shared contract lookup: supports baked/hand-moved stalls and late NPC creation.
local Quests = require(script.Parent.Config.Quests)
local World = {}
function World.Find(id: string): (BasePart?, BasePart?)
	local def = Quests.ById[id]
	local zones = workspace:FindFirstChild("Zones")
	local zone = def and zones and zones:FindFirstChild(def.ZoneId)
	local stall = zone and zone:FindFirstChild("SellStall", true)
	local npc = stall and stall:FindFirstChild("Npc")
	local root = npc and npc:FindFirstChild("HumanoidRootPart")
	local pad = zone and zone:FindFirstChild("SellPad", true)
	return if root and root:IsA("BasePart") then root else nil,
		if pad and pad:IsA("BasePart") then pad else nil
end
return World
