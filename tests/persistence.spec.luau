local P = createService()
local data = P.Load(p)
check(data ~= nil and data.Coins == 0, "new account loads defaults")
check(saved._Session.Id == "server-one", "load acquires session lock")
data.Coins = 123; data.Clovers = 7
check(P.Save(p), "autosave succeeds")
check(saved.Coins == 123 and saved._Session.Id == "server-one", "autosave retains lock and saves exact snapshot")
check(P.Load(p) == data, "duplicate loads reuse profile")
check(P.Save(p, true), "leave save succeeds")
check(saved._Session == nil and P.Get(p) == nil, "leave releases lock and removes cache")
local second = createService()
local restored = second.Load(p)
check(restored.Coins == 123 and restored.Clovers == 7, "saved currencies survive rejoin")
second.Save(p, true)
-- Legacy saves migrate carried grass without losing earned progression.
saved = { Coins = 500, Grass = 6, Level = 3 }
local legacy = createService()
local migrated = legacy.Load(p)
check(migrated.Coins == 500 and migrated.GrassByVariant.normal == 6 and migrated.Level == 3, "legacy save migrates without reset")
check(migrated.Crew ~= nil and migrated.FranchisePoints == 0, "new fields reconcile into existing saves")
legacy.Save(p, true)
-- Active locks must not be stolen; rejected loads cannot later save defaults.
saved._Session = { Id = "another-server", Expires = os.time() + 300 }
local beforeWrites = writes
local blocked = createService()
check(blocked.Load(p) == nil and p.kicked ~= false, "active session rejects concurrent login")
check(not blocked.Save(p) and writes == beforeWrites, "rejected load never saves defaults over old data")
saved._Session.Expires = os.time() - 1
local recovered = createService()
check(recovered.Load(p) ~= nil and saved._Session.Id == "server-one", "expired lock can be recovered")
-- An old server cannot overwrite a new owner, even if it still has memory.
saved._Session.Id = "new-owner"
local oldCoins = saved.Coins
check(not recovered.Save(p), "lost session ownership cancels save")
check(saved.Coins == oldCoins and saved._Session.Id == "new-owner", "cancelled save preserves current owner")
failures = true
local failed = createService()
check(failed.Load(p) == nil and not failed.Save(p), "cloud load failures never create a writable default profile")
check(warnings == 0, "load failure is handled through a safe join failure")
print("Persistence assertions passed:", checks)
