--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Marketplace = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Config = require(Shared.Config.Passes)
local Interface = require(Shared.Config.Interface)
local Ui = require(script.Parent:WaitForChild("UiKit"))
local Shop = {}
local prices = {}
local loading = {}
local function purchase(def)
	local info = prices[def.Id]
	if not Config.CheckoutEnabled or def.GamePassId <= 0 or not info or not info.IsForSale then return end
	pcall(function() Marketplace:PromptGamePassPurchase(Players.LocalPlayer, def.GamePassId) end)
end
local function paintPrice(button: TextButton, def, profile)
	if not Config.CheckoutEnabled or def.GamePassId <= 0 then
		button.Text = "Coming soon"; button.Active = false; button.Selectable = false
		button.AutoButtonColor = false; button.BackgroundColor3 = Ui.Colors.CreamShade
		return
	end
	if (profile.Passes or {})[def.Id] then button.Text = "Owned"; button.Active = false; button.Selectable = false; return end
	local info = prices[def.Id]
	button.Text = if info and info.IsForSale then "R$ " .. tostring(info.PriceInRobux) elseif info then "Off sale" else "Loading price..."
	button.Active = info ~= nil and info.IsForSale == true
	button.Selectable = button.Active
	if info or loading[def.Id] then return end
	loading[def.Id] = true
	task.spawn(function()
		local ok, result = pcall(function() return Marketplace:GetProductInfoAsync(def.GamePassId, Enum.InfoType.GamePass) end)
		loading[def.Id] = nil
		if ok then prices[def.Id] = result end
		if button.Parent then
			if ok then paintPrice(button, def, profile) else button.Text = "Price unavailable" end
		end
	end)
end
function Shop.Render(parent: Instance, profile)
	local note = Ui.Text(parent, "Permanent upgrades · one-time purchases", 15)
	note.Name = "ShopIntro"; note.Size = UDim2.new(1, 0, 0, 28); note.LayoutOrder = 0
	for index, def in Config.List do
		local banner = Instance.new("Frame")
		banner.Name = def.Id; banner.LayoutOrder = index
		banner.Size = UDim2.new(1, 0, 0, if def.Featured then Interface.Shop.FeaturedHeight else Interface.Shop.BannerHeight)
		banner.BackgroundColor3 = Ui.Colors[def.Color]; banner.Parent = parent
		Ui.Corner(banner, 12); Ui.Stroke(banner, 3)
		Ui.Shade(banner, Ui.Colors[def.Color])
		local icon = Ui.Icon(banner, Interface.Images[def.Icon], Interface.Shop.IconSize)
		icon.Position = UDim2.fromOffset(12, 16)
		local inset = if def.Featured then 154 else 124
		local name = Ui.OutlinedText(banner, string.upper(def.DisplayName), if def.Featured then 30 else 24)
		name.AutomaticSize = Enum.AutomaticSize.None
		name.Position = UDim2.fromOffset(inset, 12); name.Size = UDim2.new(1, -inset - 12, 0, 40)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextWrapped = true
		Ui.FitText(name, 18, if def.Featured then 30 else 24)
		local detail = Ui.Text(banner, def.Description, 14)
		detail.Position = UDim2.fromOffset(inset, 56); detail.Size = UDim2.new(1, -inset - 16, 0, 48)
		detail.TextXAlignment = Enum.TextXAlignment.Left
		local buy = Ui.Button(banner, "Purchase", "", function() purchase(def) end)
		buy.BackgroundColor3 = Ui.Colors.Leaf
		buy.AnchorPoint = Vector2.new(1, 1); buy.Position = UDim2.new(1, -12, 1, -12)
		buy.Size = UDim2.new(0.48, 0, 0, 44)
		paintPrice(buy, def, profile)
		local function arrange()
			local compact = banner.AbsoluteSize.X < Interface.Shop.CompactWidth
			local size = if compact then Interface.Shop.CompactIconSize else Interface.Shop.IconSize
			local left = size + 24
			icon.Size = UDim2.fromOffset(size, size)
			icon.Position = UDim2.fromOffset(8, 20)
			name.Position = UDim2.fromOffset(left, 10)
			name.Size = UDim2.new(1, -left - 12, 0, 44)
			detail.Position = UDim2.fromOffset(left, 54)
			detail.Size = UDim2.new(1, -left - 12, 0, 44)
			buy.Position = UDim2.new(1, -12, 1, -12)
			buy.Size = UDim2.new(1, -left - 12, 0, 44)
		end
		banner:GetPropertyChangedSignal("AbsoluteSize"):Connect(arrange)
		arrange()
	end
end
return Shop
