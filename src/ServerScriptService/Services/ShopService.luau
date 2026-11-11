--!strict
-- Shops: tools, backpacks, buffs/automation and zone gates.
-- One server handler per purchase type; every price/zone check happens
-- here, never on the client. Buying auto-equips tools/backpacks.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tools = require(Shared.Config.Tools)
local Backpacks = require(Shared.Config.Backpacks)
local Buffs = require(Shared.Config.Buffs)
local Zones = require(Shared.Config.Zones)

local ProfileService = require(script.Parent.ProfileService)

local ShopService = {}
local remotes: Folder

local function notify(player: Player, message: string)
	local remote = remotes:FindFirstChild("Notify") :: RemoteEvent?
	if remote then
		remote:FireClient(player, message)
	end
end

-- Plays the purchase sound on the buyer's client.
local function bought(player: Player, message: string)
	notify(player, message)
	local remote = remotes:FindFirstChild("BuyFeedback") :: RemoteEvent?
	if remote then
		remote:FireClient(player)
	end
end

local function highestUnlockedZoneIndex(profile): number
	local highest = 1
	for zoneId in profile.UnlockedZoneIds do
		local index = Zones.IndexById[zoneId]
		if index and index > highest then
			highest = index
		end
	end
	return highest
end

local function canAffordAndUnlocked(player, profile, price: number, requiredZone: number): boolean
	if highestUnlockedZoneIndex(profile) < requiredZone then
		notify(player, "Unlock that zone first!")
		return false
	end
	if profile.Coins < price then
		notify(player, "Not enough Coins.")
		return false
	end
	return true
end

local function buyTool(player: Player, toolId: string)
	local profile = ProfileService.Get(player)
	local def = Tools.ById[toolId]
	if not profile or not def then
		return
	end
	if profile.OwnedToolIds[toolId] then
		profile.EquippedToolId = toolId -- re-buying an owned tool just equips it
	else
		if not canAffordAndUnlocked(player, profile, def.Price, def.RequiredZone) then
			return
		end
		profile.Coins -= def.Price
		profile.OwnedToolIds[toolId] = true
		profile.EquippedToolId = toolId
		bought(player, "Bought " .. def.DisplayName .. "!")
	end
	ProfileService.NotifyChanged(player)
end

local function buyBackpack(player: Player, backpackId: string)
	local profile = ProfileService.Get(player)
	local def = Backpacks.ById[backpackId]
	if not profile or not def then
		return
	end
	if profile.OwnedBackpackIds[backpackId] then
		profile.EquippedBackpackId = backpackId
	else
		if not canAffordAndUnlocked(player, profile, def.Price, def.RequiredZone) then
			return
		end
		profile.Coins -= def.Price
		profile.OwnedBackpackIds[backpackId] = true
		profile.EquippedBackpackId = backpackId
		bought(player, "Bought " .. def.DisplayName .. "!")
	end
	ProfileService.NotifyChanged(player)
end

local function buyBuff(player: Player, buffId: string)
	local profile = ProfileService.Get(player)
	local def = Buffs.ById[buffId]
	if not profile or not def then
		return
	end
	local stacks = profile.BuffStacks[buffId] or 0
	if stacks >= def.MaxStacks then
		notify(player, def.DisplayName .. " is maxed out.")
		return
	end
	if not canAffordAndUnlocked(player, profile, def.Price, def.RequiredZone) then
		return
	end
	profile.Coins -= def.Price
	profile.BuffStacks[buffId] = stacks + 1
	bought(player, "Bought " .. def.DisplayName .. "!")
	ProfileService.NotifyChanged(player)
end

local function unlockZone(player: Player, zoneId: string)
	local profile = ProfileService.Get(player)
	local def = Zones.ById[zoneId]
	if not profile or not def or profile.UnlockedZoneIds[zoneId] then
		return
	end
	-- Zones unlock in order: no skipping the farm to reach the golf estate.
	local index = Zones.IndexById[zoneId]
	local previous = Zones.List[index - 1]
	if previous and not profile.UnlockedZoneIds[previous.Id] then
		notify(player, "Unlock " .. previous.DisplayName .. " first!")
		return
	end
	if profile.Coins < def.UnlockPrice then
		notify(player, "Not enough Coins to unlock " .. def.DisplayName .. ".")
		return
	end
	profile.Coins -= def.UnlockPrice
	profile.UnlockedZoneIds[zoneId] = true
	bought(player, "Unlocked " .. def.DisplayName .. "!")
	ProfileService.NotifyChanged(player)
end

function ShopService.Init(remoteFolder: Folder)
	remotes = remoteFolder;
	(remoteFolder:WaitForChild("BuyTool") :: RemoteEvent).OnServerEvent:Connect(buyTool);
	(remoteFolder:WaitForChild("BuyBackpack") :: RemoteEvent).OnServerEvent:Connect(buyBackpack);
	(remoteFolder:WaitForChild("BuyBuff") :: RemoteEvent).OnServerEvent:Connect(buyBuff);
	(remoteFolder:WaitForChild("UnlockZone") :: RemoteEvent).OnServerEvent:Connect(unlockZone)
end

return ShopService
