local signal = function() return { Connect = function() end } end
local players = { PlayerAdded = signal(), PlayerRemoving = signal() }
local p = { UserId = 100, Parent = players, kicked = false }
function p:Kick(message) self.kicked = message end
local studio = false
local failures = false
local saved = nil
local writes = 0
local datastore = {}
function datastore:UpdateAsync(key, transform)
	if failures then error("transient test failure") end
	local nextData = transform(saved)
	if nextData then saved = nextData; writes += 1 end
	return nextData
end
local storeService = {}
function storeService:GetDataStore() return datastore end
local http = {}
function http:GenerateGUID() return "test-session" end
-- Clone snapshots rather than serialize: profiles contain plain table values.
local function clone(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for k, v in value do result[k] = clone(v) end
	return result
end
function http:JSONEncode(value) return clone(value) end
function http:JSONDecode(value) return clone(value) end
local game = { JobId = "server-one" }
function game:GetService(name)
	return ({ Players = players, DataStoreService = storeService,
		RunService = { IsStudio = function() return studio end }, HttpService = http,
		ReplicatedStorage = { WaitForChild = function() return { Config = {} } end } })[name]
end
local task = { wait = function() end }
local warnings = 0
local warn = function() warnings += 1 end
local checks = 0
local function check(condition, text) assert(condition, text); checks += 1 end
