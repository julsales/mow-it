--!strict
-- The local player's profile on the client, in one place. RemoteEvents
-- queue events only for their FIRST listener, so several scripts each
-- connecting to ProfileUpdated could miss the initial push. Everyone
-- requires this module instead and reads Get() / listens to Changed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientState = {}

local profile: any = nil
local changed = Instance.new("BindableEvent")

ClientState.Changed = changed.Event -- fires (profile)

function ClientState.Get(): any
	return profile
end

local remotes = ReplicatedStorage:WaitForChild("Remotes");
(remotes:WaitForChild("ProfileUpdated") :: RemoteEvent).OnClientEvent:Connect(function(newProfile)
	profile = newProfile
	changed:Fire(newProfile)
end)

return ClientState
