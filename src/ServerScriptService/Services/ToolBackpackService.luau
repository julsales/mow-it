--!strict
-- Owned tools as real Roblox Tools, so Roblox's default hotbar and backpack
-- (keys 1-9, the backpack button, search) list and switch them. The Tools
-- carry no handle: the 3D model stays ToolVisualService's job. Holding a
-- Tool equips it on the profile (ShopService path, server-validated);
-- holding none puts the tool away (no model, no cutting).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tools = require(ReplicatedStorage:WaitForChild("Shared").Config.Tools)
local Format = require(ReplicatedStorage.Shared.Format)
local ProfileService = require(script.Parent.ProfileService)
local ShopService = require(script.Parent.ShopService)
local ToolVisualService = require(script.Parent.ToolVisualService)

local ToolBackpackService = {}

-- Last EquippedToolId this service put in the hand, per player: a new value
-- (a purchase at a stall) is handed to the player once.
local handed: { [Player]: string } = {}

local function owned(player: Player): { [string]: Tool }
	local found = {}
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		for _, child in if container then container:GetChildren() else {} do
			local id = child:GetAttribute("ToolId")
			if child:IsA("Tool") and type(id) == "string" then found[id] = child end
		end
	end
	return found
end

local function make(player: Player, def): Tool
	local tool = Instance.new("Tool")
	tool.Name = def.DisplayName
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.ToolTip = "Power " .. Format.Number(def.Power)
	tool:SetAttribute("ToolId", def.Id)
	tool.Equipped:Connect(function()
		ShopService.BuyTool(player, def.Id)
		ToolVisualService.Refresh(player)
	end)
	tool.Unequipped:Connect(function()
		task.defer(ToolVisualService.Refresh, player)
	end)
	return tool
end

local function sync(player: Player)
	local profile = ProfileService.Get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not profile or not backpack then
		return
	end
	local tools = owned(player)
	-- Ladder order, so the hotbar fills cheapest to best.
	for _, def in Tools.List do
		if profile.OwnedToolIds[def.Id] and not tools[def.Id] then
			tools[def.Id] = make(player, def)
			tools[def.Id].Parent = backpack
		end
	end
	for id, tool in tools do
		if not profile.OwnedToolIds[id] then
			tool:Destroy() -- Franchise reset
			tools[id] = nil
		end
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local wanted = tools[profile.EquippedToolId]
	if humanoid and wanted and handed[player] ~= profile.EquippedToolId then
		handed[player] = profile.EquippedToolId
		humanoid:EquipTool(wanted)
	end
end

function ToolBackpackService.Init()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			handed[player] = nil -- respawn: a fresh Backpack, hand the tool again
			character:WaitForChild("Humanoid", 10)
			player:WaitForChild("Backpack", 10)
			sync(player)
		end)
		if player.Character then
			task.spawn(sync, player)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		handed[player] = nil
	end)
	ProfileService.OnChanged(function(player)
		task.spawn(sync, player)
	end)
end

return ToolBackpackService
