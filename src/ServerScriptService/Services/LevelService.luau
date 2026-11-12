--!strict
-- Company Level: turns experience into levels (curve and sources in
-- Shared/Config/CompanyLevel.luau). Callers add XP while they change the
-- profile and push it once with ProfileService.NotifyChanged; level-ups
-- are announced to the player's client (LevelUp remote) for the HUD.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CompanyLevel = require(Shared.Config.CompanyLevel)

local ProfileService = require(script.Parent.ProfileService)

local LevelService = {}
local remotes: Folder?

-- Adds XP to a loaded profile and levels it up as far as it goes. Does not
-- push the profile: the caller does, together with its own changes.
function LevelService.AddXp(player: Player, amount: number)
	local profile = ProfileService.Get(player)
	if not profile or amount <= 0 or amount ~= amount then
		return
	end
	profile.Xp += amount
	local before = profile.Level
	while profile.Level < CompanyLevel.MaxLevel and profile.Xp >= CompanyLevel.XpToNext(profile.Level) do
		profile.Xp -= CompanyLevel.XpToNext(profile.Level)
		profile.Level += 1
	end
	if profile.Level >= CompanyLevel.MaxLevel then
		profile.Xp = 0
	end
	if profile.Level > before and remotes then
		(remotes:FindFirstChild("LevelUp") :: RemoteEvent):FireClient(player, profile.Level)
	end
end

function LevelService.Init(remoteFolder: Folder)
	remotes = remoteFolder
end

return LevelService
