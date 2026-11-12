--!strict
-- The land of this session, on the client: whose it is and which
-- expansions are open on it (published by LandService as Workspace
-- attributes). Gates, sell pads and guides follow the LAND; shops and the
-- HUD follow the local player's own profile (ClientState).
-- In a lobby-only server nothing is published and no expansion is open.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LandState = {}

local changed = Instance.new("BindableEvent")
LandState.Changed = changed.Event

local unlocked: { [string]: boolean } = {}

local function read()
	table.clear(unlocked)
	local list = Workspace:GetAttribute("LandUnlocked")
	if type(list) == "string" then
		for _, id in string.split(list, ",") do
			if id ~= "" then
				unlocked[id] = true
			end
		end
	end
	changed:Fire()
end

function LandState.IsUnlocked(zoneId: string): boolean
	return unlocked[zoneId] == true
end

-- The set of open expansions (read-only; same shape as a profile's UnlockedZoneIds).
function LandState.Unlocked(): { [string]: boolean }
	return unlocked
end

function LandState.IsHost(): boolean
	return Workspace:GetAttribute("LandHostUserId") == Players.LocalPlayer.UserId
end

function LandState.HostName(): string
	local name = Workspace:GetAttribute("LandHostName")
	return if type(name) == "string" then name else ""
end

for _, attribute in { "LandUnlocked", "LandHostUserId", "LandHostName" } do
	Workspace:GetAttributeChangedSignal(attribute):Connect(read)
end
read()

return LandState
