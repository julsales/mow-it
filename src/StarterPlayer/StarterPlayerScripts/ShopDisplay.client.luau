--!strict
-- Paints the physical tool shops (Map/ShopDisplay on the server) for the
-- local player: each item's tag and prompt say Buy $price / Equip /
-- Equipped / Zone N, from this player's profile. Also opens the Shop panel
-- from a shop counter prompt ("OpenShopPrompt").

local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Format = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Format)
local Zones = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Zones)
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local items: { [BasePart]: boolean } = {}

local GREEN = Color3.fromRGB(40, 140, 60)
local BLUE = Color3.fromRGB(40, 100, 200)
local GRAY = Color3.fromRGB(110, 110, 110)
local RED = Color3.fromRGB(180, 60, 50)

local function highestZone(profile): number
	local highest = 1
	for zoneId in profile.UnlockedZoneIds do
		local index = Zones.IndexById[zoneId]
		if index and index > highest then
			highest = index
		end
	end
	return highest
end

local function paint(item: BasePart)
	local profile = ClientState.Get()
	local toolId = item:GetAttribute("ToolId") :: string?
	local prompt = item:FindFirstChild("ShopItemPrompt") :: ProximityPrompt?
	local tag = item:FindFirstChild("PriceTag")
	local status = tag and tag:FindFirstChild("Status", true) :: TextLabel?
	if not profile or not toolId or not prompt or not status then
		return
	end
	local price = (item:GetAttribute("Price") :: number?) or 0
	local zone = (item:GetAttribute("RequiredZone") :: number?) or 1
	if profile.EquippedToolId == toolId then
		status.Text, status.TextColor3 = "Equipped", GRAY
		prompt.Enabled = false
	elseif profile.OwnedToolIds[toolId] then
		status.Text, status.TextColor3 = "Owned", BLUE
		prompt.ActionText, prompt.Enabled = "Equip", true
	elseif highestZone(profile) < zone then
		status.Text, status.TextColor3 = "Zone " .. zone, RED
		prompt.Enabled = false
	else
		status.Text = "$" .. Format.Number(price)
		status.TextColor3 = if profile.Coins >= price then GREEN else RED
		prompt.ActionText, prompt.Enabled = "Buy", true
	end
end

local function paintAll()
	for item in items do
		if item.Parent then
			paint(item)
		else
			items[item] = nil
		end
	end
end

local function consider(instance: Instance)
	if instance.Name == "ShopItem" and instance:IsA("BasePart") then
		items[instance] = true
		-- Its prompt/tag replicate right after the part.
		task.defer(paint, instance)
	end
end
Workspace.DescendantAdded:Connect(consider)
for _, d in Workspace:GetDescendants() do
	consider(d)
end
ClientState.Changed:Connect(paintAll)

-- Counter prompt opens the full Shop panel (Shop.client.luau).
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "OpenShopPrompt" then
		local open = script.Parent:FindFirstChild("OpenShop")
		if open and open:IsA("BindableEvent") then
			open:Fire()
		end
	end
end)

