-- Assert-based unit coverage for the actual shared rules, also runnable in Studio.
return function(M)
	local Rules, Bag, Tuning, Zones = M.ProgressionRules, M.GrassBag, M.Progression, M.Zones
	local checks = 0
	local function check(value, message)
		assert(value, message)
		checks += 1
	end
	local function profile()
		local p = Rules.Defaults()
		p.Coins = 0; p.GrassByVariant = {}; p.LifetimeGrass = 0
		p.Level = 1; p.Xp = 0; p.BuffStacks = {}
		p.EquippedBackpackId = "pocket"; p.UnlockedZoneIds = { front_yard = true }
		p.OwnedToolIds = { nail_clipper = true }; p.OwnedBackpackIds = { pocket = true }
		return p
	end
	local p = profile()
	check(Rules.CrewSlots(p) == 1, "starts with one crew slot")
	local a = Rules.AddCrew(p, "garden_snail")
	check(a ~= nil, "adds catalog crew")
	check(Rules.AddCrew(p, "not_real") == nil, "rejects unknown crew")
	p.EquippedCrew = { a }
	check(Rules.AwardCoins(p, 100) == 102 and p.RunCoins == 102 and p.LifetimeCoins == 102, "crew earnings feed all coin counters once")
	check(not Rules.MergeCrew(p, a), "merge cannot invent copies")
	local b, c = Rules.AddCrew(p, "garden_snail"), Rules.AddCrew(p, "garden_snail")
	p.EquippedCrew = { a, b, c }
	check(Rules.MergeCrew(p, a), "merges three equal copies")
	check(Rules.CrewCount(p) == 1 and p.Crew[a].Evolution == 1 and #p.EquippedCrew == 1, "merge consumes copies and removes consumed equip references")
	check(not Rules.MergeCrew(p, a), "repeated merge has no extra payout")
	p.Crew[a].Evolution = Tuning.MaxEvolution
	check(not Rules.MergeCrew(p, a), "caps evolution")
	p.Level = 20; p.FranchiseRanks.extra_crew_slot = 2
	check(Rules.CrewSlots(p) == 7, "level and permanent crew slots stack")
	check(Bag.Add(p, "golden", 8) == 8 and Bag.Add(p, "wet", 5) == 2, "mixed variants respect total capacity")
	check(Bag.Total(p) == 10 and Bag.SellValue(p, 3) == (8 * 20 + 2 * 2) * 3, "selling uses each variant multiplier")
	check(Bag.Add(p, "normal", 10) == 0, "full backpack rejects overflow")
	check(Bag.Add(p, "normal", -10) == 0, "negative grass cannot remove inventory")
	Bag.Clear(p); check(Bag.Total(p) == 0, "selling clears all variants")
	local q = profile(); q.RunCoins = 100000000
	check(Rules.FranchiseAward(q) == 0, "earnings alone do not skip late-game expansion gate")
	q.UnlockedZoneIds.mega_fields = true
	check(Rules.FranchiseAward(q) > 0, "late-game run awards franchise points")
	local crew = Rules.AddCrew(q, "garden_snail")
	q.EquippedCrew = { crew }; q.Plots = { yard = { ReadyAt = 100 } }; q.Clovers = 85
	q.FranchiseRanks.company_multiplier = 2; q.Crew[crew].Mode = "Station"
	q.Crew[crew].Position = { 1, 2, 3 }; q.BuffStacks.auto_sell = 1
	check(Rules.Franchise(q), "qualified franchise resets the run")
	check(q.Coins == 0 and q.RunCoins == 0 and q.Level == 1 and q.Xp == 0, "run money and XP reset")
	check(q.EquippedToolId == "nail_clipper" and q.EquippedBackpackId == "pocket", "starter equipment restored")
	check(not q.UnlockedZoneIds.mega_fields and next(q.Plots) == nil and next(q.BuffStacks) == nil, "land, plots and automation reset")
	check(q.Crew[crew] ~= nil and q.Clovers == 85 and q.FranchiseRanks.company_multiplier == 2, "collection and permanent progression survive")
	check(q.Crew[crew].Mode == "Follow" and q.Crew[crew].Position == nil, "station references reset with land")
	check(not Rules.Franchise(q), "franchise cannot be replayed for duplicate points")
	q.FranchisePoints = 1
	check(Rules.BuyNode(q, "extra_crew_slot") and q.FranchisePoints == 0, "node consumes exact points")
	check(not Rules.BuyNode(q, "extra_crew_slot") and not Rules.BuyNode(q, "missing"), "unaffordable/unknown nodes rejected")
	q.FranchisePoints = 100
	for _ = 1, 20 do Rules.BuyNode(q, "extra_crew_slot") end
	check(q.FranchiseRanks.extra_crew_slot == 3, "node cannot exceed max rank")
	local offline = profile(); local uid = Rules.AddCrew(offline, "garden_snail")
	offline.EquippedCrew = { uid }; offline.Crew[uid].Mode = "Station"; offline.LastSeen = 1000
	Rules.AccrueOffline(offline, 100000)
	check(offline.OfflineGrass == 0, "offline cap starts at zero")
	offline.FranchiseRanks.offline_cap = 1
	Rules.AccrueOffline(offline, 100000)
	check(offline.OfflineGrass == 72, "offline production caps elapsed time at two hours")
	offline.OfflineGrass = 0; offline.Crew[uid].Mode = "Follow"
	Rules.AccrueOffline(offline, 100000)
	check(offline.OfflineGrass == 0, "follow crew do not produce offline")
	offline.Crew[uid].Mode = "Station"; offline.Crew[uid].ZoneId = "mega_fields"
	Rules.AccrueOffline(offline, 100000)
	check(offline.OfflineGrass == 0, "locked expansion cannot produce offline")
	local epoch, shelf = Rules.Shelf(1700000000)
	local epoch2, shelf2 = Rules.Shelf(1700000001)
	check(epoch == epoch2 and #shelf == #shelf2, "same server-time interval produces identical shelf")
	for index, item in shelf do check(item.Id == shelf2[index].Id and item.Price > 0, "shelf rows deterministic with positive prices") end
	check(select(1, Rules.Shelf((epoch + 1) * Tuning.RestockSeconds)) == epoch + 1, "restock boundary advances epoch")
	print("Progression assertions passed:", checks)
end
