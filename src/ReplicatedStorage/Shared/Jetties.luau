--!strict
-- The jetties boats sail between (Config/Travel): contract Models named
-- "Jetty", one inside each island past the home one (Workspace/Zones/<id>)
-- and one inside every personal base. A jetty's pivot is the middle of its
-- deck, looking out to sea.

local Workspace = game:GetService("Workspace")

local Bases = require(script.Parent.Bases)
local Zones = require(script.Parent.Config.Zones)

local Jetties = {}

Jetties.Home = "Home" -- the destination name for the player's own base

local function asModel(instance: Instance?): Model?
	return if instance and instance:IsA("Model") then instance else nil
end

-- An island's jetty, or nil when it has none.
function Jetties.OfZone(zoneId: string): Model?
	local zones = Workspace:FindFirstChild("Zones")
	local island = zones and zones:FindFirstChild(zoneId)
	return asModel(island and island:FindFirstChild("Jetty"))
end

-- The jetty on a player's own base, or nil.
function Jetties.OfBase(userId: number): Model?
	return asModel(Bases.Piece(userId, "Jetty"))
end

-- The jetty a destination name stands for, for this player: Jetties.Home
-- or the id of an island they have unlocked. Nil when they may not go.
function Jetties.Destination(userId: number, unlocked: { [string]: boolean }, destination: string): Model?
	if destination == Jetties.Home then
		return Jetties.OfBase(userId)
	end
	return if Zones.ById[destination] and unlocked[destination] then Jetties.OfZone(destination) else nil
end

-- Every jetty this player can board, with the destination name of each.
function Jetties.Usable(userId: number, unlocked: { [string]: boolean }): { [string]: Model }
	local list = {}
	local home = Jetties.OfBase(userId)
	if home then
		list[Jetties.Home] = home
	end
	for _, zone in Zones.List do
		local jetty = if unlocked[zone.Id] then Jetties.OfZone(zone.Id) else nil
		if jetty then
			list[zone.Id] = jetty
		end
	end
	return list
end

-- Where someone stands on a jetty: on its deck, facing the land.
function Jetties.Landing(jetty: Model): CFrame
	local pivot = jetty:GetPivot()
	return CFrame.lookAt(pivot.Position, pivot.Position - pivot.LookVector)
end

return Jetties
