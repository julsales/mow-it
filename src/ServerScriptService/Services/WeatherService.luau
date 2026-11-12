--!strict
-- Weather changes harvest odds, without overwriting hand-edited lighting.
local Shared = game:GetService("ReplicatedStorage").Shared
local Weather = require(Shared.Config.Weather)
local Tuning = require(Shared.Config.Progression)
local WeatherService = {}
local current = Weather.List[1]
function WeatherService.Variant(profile): string
	local bonus = 1 + (profile.FranchiseRanks.golden_touch or 0) * Tuning.VariantBonusPerRank
	return if math.random() < current.VariantChanceBonus * bonus then current.VariantId else "normal"
end
function WeatherService.Init(remotes: Folder)
	task.spawn(function()
		while true do
			workspace:SetAttribute("WeatherId", current.Id)
			workspace:SetAttribute("WeatherEndsAt", workspace:GetServerTimeNow() + current.DurationSeconds);
			(remotes.Notify :: RemoteEvent):FireAllClients(current.DisplayName .. " — watch for special grass!")
			task.wait(current.DurationSeconds)
			local total = 0
			for _, def in Weather.List do total += def.Weight end
			local roll = math.random() * total
			for _, def in Weather.List do
				roll -= def.Weight
				if roll <= 0 then current = def; break end
			end
		end
	end)
end
return WeatherService
