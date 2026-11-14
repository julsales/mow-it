--!strict
-- The hay yard's state and rules, shared by server and client (numbers in
-- Config/HayYard.luau). A profile carries:
--   profile.Hay = {
--     Level,          baler upgrade level (Config Levels)
--     Units, Value,   grass waiting in the hopper and what it is worth
--     Bales,          { { Id, Value, Golden } } pressed, waiting on the stack
--     NextId,         next bale id
--     Stock, StockValue  bales in the silo for customers, and their worth
--   }

local Config = require(script.Parent.Config.HayYard)
local GrassBag = require(script.Parent.GrassBag)

export type Bale = { Id: number, Value: number, Golden: boolean }
export type State = {
	Level: number,
	Units: number,
	Value: number,
	Bales: { Bale },
	NextId: number,
	Stock: number,
	StockValue: number,
}

local Hay = {}

function Hay.Defaults(): State
	return { Level = 1, Units = 0, Value = 0, Bales = {}, NextId = 1, Stock = 0, StockValue = 0 }
end

-- The profile's hay state, with anything missing filled in (old saves).
function Hay.State(profile: any): State
	local state = profile.Hay
	if type(state) ~= "table" then
		state = Hay.Defaults()
		profile.Hay = state
	end
	for key, value in Hay.Defaults() :: any do
		if typeof(state[key]) ~= typeof(value) then
			state[key] = value
		end
	end
	return state
end

function Hay.Level(profile: any): Config.Level
	local levels = Config.Levels
	return levels[math.clamp(Hay.State(profile).Level, 1, #levels)]
end

-- Bales the stack holds before the baler has to wait.
function Hay.MaxStack(profile: any): number
	return Hay.Level(profile).Layers * #Config.Stack.Columns
end

-- Grass units pressed into one bale: bigger storage, richer bales.
function Hay.BaleUnits(profile: any): number
	return math.max(Config.GrassPerBale, math.ceil(GrassBag.Capacity(profile) / Config.BalesPerFullBag))
end

function Hay.IsStackFull(profile: any): boolean
	return #Hay.State(profile).Bales >= Hay.MaxStack(profile)
end

-- The baler runs while it has grass and room on the stack.
function Hay.IsWorking(profile: any): boolean
	return Hay.State(profile).Units > 0 and not Hay.IsStackFull(profile)
end

-- 0..1, how full the hopper looks (a full storage load fills it).
function Hay.HopperRatio(profile: any): number
	return math.clamp(Hay.State(profile).Units / math.max(GrassBag.Capacity(profile), 1), 0, 1)
end

return Hay
