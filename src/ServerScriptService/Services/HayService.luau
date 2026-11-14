--!strict
-- Selling, server side (spec core-mowing-loop "Selling grass"; numbers in
-- Shared/Config/HayYard.luau; state shape in Shared/Hay.luau):
--
--   Load      grass leaves the player's storage and waits in the hopper
--   press     the baler turns hopper grass into bales, one every
--             Level.BaleSeconds, while the stack has room
--   Sell      the player clicks a bale: Coins now, the bale goes to the silo
--   customers while the silo has stock, customers walk up and buy bales;
--             their tip lands when they reach the counter
--
-- Clients only draw this (StarterPlayerScripts/HayYard.client): bales and
-- the machine's state come from the profile, customers from HayCustomer.
-- Automation later plugs in here: a conveyor is "Sell without the click",
-- a truck is another customer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.HayYard)
local CompanyLevel = require(Shared.Config.CompanyLevel)
local Zones = require(Shared.Config.Zones)
local GrassBag = require(Shared.GrassBag)
local Hay = require(Shared.Hay)
local Rules = require(Shared.ProgressionRules)

local ProfileService = require(script.Parent.ProfileService)
local LevelService = require(script.Parent.LevelService)
local Yard = require(script.Parent.Map.HayYard)

local HayService = {}

local TICK = 0.2

local remotes: Folder
local yard: Model? = nil
local nextBaleAt: { [Player]: number } = {}
local nextCustomerAt: { [Player]: number } = {}
local rng = Random.new()

-- Coins the carried grass is worth: each variant's multiplier, times the
-- best area THIS player has unlocked (helpers on a richer land still sell
-- at their own progression).
function HayService.LoadValue(profile: any): number
	local bestValue = 1
	for zoneId in profile.UnlockedZoneIds do
		local zone = Zones.ById[zoneId]
		if zone and zone.GrassValue > bestValue then
			bestValue = zone.GrassValue
		end
	end
	return GrassBag.SellValue(profile, bestValue)
end

-- True when this place has a hay yard to sell through.
function HayService.HasYard(): boolean
	return yard ~= nil
end

-- Moves everything the player carries into the baler's hopper.
function HayService.Load(player: Player): boolean
	local profile = ProfileService.Get(player)
	local units = profile and GrassBag.Total(profile) or 0
	if not profile or units <= 0 then
		return false
	end
	local state = Hay.State(profile)
	state.Units += units
	state.Value += HayService.LoadValue(profile)
	GrassBag.Clear(profile)
	ProfileService.NotifyChanged(player);
	(remotes:FindFirstChild("HayLoaded") :: RemoteEvent):FireClient(player, units)
	return true
end

local function press(player: Player, profile: any, now: number)
	if not Hay.IsWorking(profile) then
		nextBaleAt[player] = nil
		return
	end
	local level = Hay.Level(profile)
	local due = nextBaleAt[player]
	if not due then
		nextBaleAt[player] = now + level.BaleSeconds
		return
	end
	if now < due then
		return
	end
	local state = Hay.State(profile)
	local take = math.min(state.Units, Hay.BaleUnits(profile))
	local value = state.Value * take / state.Units
	state.Units -= take
	state.Value -= value
	if state.Units <= 0 then
		state.Units, state.Value = 0, 0
	end
	local golden = rng:NextNumber() < Config.GoldenChance
	value *= level.ValueMultiplier * (if golden then Config.GoldenMultiplier else 1)
	table.insert(state.Bales, { Id = state.NextId, Value = value, Golden = golden })
	state.NextId += 1
	nextBaleAt[player] = now + level.BaleSeconds
	ProfileService.NotifyChanged(player)
end

local function nearYard(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local stack = yard and yard:FindFirstChild("BaleStack")
	if not root or not stack or not stack:IsA("Model") then
		return false
	end
	return (root.Position - stack:GetPivot().Position).Magnitude <= Config.SellDistance
end

-- The player clicked a bale on the stack.
function HayService.Sell(player: Player, baleId: number)
	local profile = ProfileService.Get(player)
	if not profile or not nearYard(player) then
		return
	end
	local state = Hay.State(profile)
	for index, bale in state.Bales do
		if bale.Id == baleId then
			table.remove(state.Bales, index)
			local earned = Rules.AwardCoins(profile, bale.Value)
			profile.SellCount += 1
			if state.Stock < Config.SiloCapacity then
				state.Stock += 1
				state.StockValue += bale.Value
			end
			LevelService.AddXp(player, earned * CompanyLevel.XpPerCoinSold)
			ProfileService.NotifyChanged(player);
			(remotes:FindFirstChild("SellFeedback") :: RemoteEvent):FireClient(player, earned, baleId)
			return
		end
	end
end

local function customers(player: Player, profile: any, now: number)
	local state = Hay.State(profile)
	if state.Stock <= 0 then
		nextCustomerAt[player] = nil
		return
	end
	local due = nextCustomerAt[player]
	local every = Config.CustomerEvery
	if not due then
		nextCustomerAt[player] = now + rng:NextNumber(every.Min, every.Max)
		return
	end
	if now < due then
		return
	end
	nextCustomerAt[player] = now + rng:NextNumber(every.Min, every.Max)
	local bales = math.min(state.Stock, rng:NextInteger(Config.CustomerBales.Min, Config.CustomerBales.Max))
	local share = state.StockValue * bales / state.Stock
	state.Stock -= bales
	state.StockValue = if state.Stock > 0 then state.StockValue - share else 0
	ProfileService.NotifyChanged(player)
	local walk = Config.CustomerWalkSeconds;
	(remotes:FindFirstChild("HayCustomer") :: RemoteEvent):FireClient(player, bales, walk)
	-- The tip is paid when the customer reaches the counter.
	task.delay(walk, function()
		local current = ProfileService.Get(player)
		if current ~= profile then
			return
		end
		local tip = Rules.AwardCoins(profile, share * Config.TipRate)
		if tip > 0 then
			ProfileService.NotifyChanged(player);
			(remotes:FindFirstChild("HayTip") :: RemoteEvent):FireClient(player, tip)
		end
	end)
end

function HayService.Init(remoteFolder: Folder)
	remotes = remoteFolder
	Yard.EnsureBuilt()
	Yard.BuildCustomers()
	yard = Yard.Find()
	if not yard then
		warn("[MowIt][HayYard] No HayYard in this place: sell pads pay out directly.")
		return
	end

	local lastAction: { [Player]: number } = {};
	(remotes:WaitForChild("HayAction") :: RemoteEvent).OnServerEvent:Connect(function(player, action, baleId)
		local now = os.clock()
		if now - (lastAction[player] or 0) < 0.05 then
			return
		end
		lastAction[player] = now
		if action == "Sell" and type(baleId) == "number" then
			HayService.Sell(player, baleId)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		nextBaleAt[player], nextCustomerAt[player], lastAction[player] = nil, nil, nil
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local profile = ProfileService.Get(player)
				if profile then
					press(player, profile, now)
					customers(player, profile, now)
				end
			end
		end
	end)
end

return HayService
