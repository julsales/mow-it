-- Executed by tools/test-services.py against production modules.
local function signal()
	local signal = { listeners = {} }
	function signal:Connect(callback) table.insert(self.listeners, callback); return { Disconnect = function() end } end
	function signal:Fire(...) for _, callback in self.listeners do callback(...) end end
	return signal
end
local player = { UserId = 1, DisplayName = "Host" }
local guest = { UserId = 2, DisplayName = "Guest" }
local actors = { player, guest }
local Players = { PlayerRemoving = signal() }
function Players:GetPlayers() return actors end
local PlayersFolder = Players
player.Parent = PlayersFolder; guest.Parent = PlayersFolder
local function newProfile()
	local p = M.ProgressionRules.Defaults()
	p.Coins = 0; p.GrassByVariant = {}; p.LifetimeGrass = 0; p.Level = 1; p.Xp = 0
	p.UnlockedZoneIds = { front_yard = true }; p.BuffStacks = {}
	p.OwnedToolIds = { nail_clipper = true }; p.EquippedToolId = "nail_clipper"
	p.EquippedBackpackId = "pocket"
	return p
end
local profiles = { [player] = newProfile(), [guest] = newProfile() }
local notifications = {}
local Profiles = {}
function Profiles.Get(p) return profiles[p] end
function Profiles.NotifyChanged(p) end
local Levels = {}
function Levels.AddXp(p, amount) profiles[p].Xp += amount end
local Land = {}
function Land.IsHost(p) return p == player end
function Land.IsUnlocked(id) return profiles[player].UnlockedZoneIds[id] == true end
local clock = 1000
local workspace = { attributes = {} }
function workspace:SetAttribute(name, value) self.attributes[name] = value end
function workspace:GetAttribute(name) return self.attributes[name] end
function workspace:GetServerTimeNow() return clock end
local ReplicatedStorage = { Shared = { Config = {} } }
function ReplicatedStorage:WaitForChild() return self.Shared end
local services = { Players = Players, ReplicatedStorage = ReplicatedStorage }
local game = {}
function game:GetService(name) return services[name] end
local task = { spawn = function() end }
local script = { Parent = {} }
local remotes = {}
for _, name in { "Notify", "FranchiseOffer", "GameAction" } do
	remotes[name] = { OnServerEvent = signal() }
	local remote = remotes[name]
	function remote:FireClient(p, message) table.insert(notifications, { player = p, message = message }) end
end
local checks = 0
local function check(condition, label) assert(condition, label); checks += 1 end
