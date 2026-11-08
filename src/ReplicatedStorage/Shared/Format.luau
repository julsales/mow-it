--!strict
-- Number formatting for HUD/shop (1.25K, 3.4M, ...). Shared by client UI.

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp" }

local Format = {}

function Format.Number(value: number): string
	if value < 1000 then
		return string.format("%d", math.floor(value))
	end
	local tier = math.floor(math.log10(value) / 3)
	local suffix = SUFFIXES[tier] or "?"
	local scaled = value / (10 ^ (tier * 3))
	if scaled >= 100 then
		return string.format("%.0f%s", scaled, suffix)
	elseif scaled >= 10 then
		return string.format("%.1f%s", scaled, suffix)
	else
		return string.format("%.2f%s", scaled, suffix)
	end
end

function Format.Coins(value: number): string
	return Format.Number(value) .. " Coins"
end

return Format
