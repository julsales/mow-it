--!strict
-- Which islands are open for the local player. The islands are shared by
-- everybody on the server, but each player unlocks them for themselves
-- (their own profile): gates, drop-off pads, planting beds and guides on
-- this client follow the local player's own progress.

local ClientState = require(script.Parent:WaitForChild("ClientState"))

local LandState = {}

local changed = Instance.new("BindableEvent")
LandState.Changed = changed.Event

local unlocked: { [string]: boolean } = {}

local function read(profile: any)
	local now = if profile and type(profile.UnlockedZoneIds) == "table" then profile.UnlockedZoneIds else {}
	local same = true
	for id in now do
		same = same and unlocked[id] == true
	end
	for id in unlocked do
		same = same and now[id] == true
	end
	if not same then
		unlocked = table.clone(now)
		changed:Fire()
	end
end

function LandState.IsUnlocked(zoneId: string): boolean
	return unlocked[zoneId] == true
end

-- The set of open islands (read-only; a profile's UnlockedZoneIds).
function LandState.Unlocked(): { [string]: boolean }
	return unlocked
end

ClientState.Changed:Connect(read)
read(ClientState.Get())

return LandState
