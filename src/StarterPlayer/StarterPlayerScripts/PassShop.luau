--!strict
-- Passes page (boards 1-2): three tall offer cards over two wide ones, the
-- last a "More to grow" teaser. Narrow windows fall back to two columns of
-- tall cards. Checkout stays off until entitlements are verified (Passes).
local Shared = game:GetService("ReplicatedStorage").Shared
local Marketplace = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Config = require(Shared.Config.Passes)
local Interface = require(Shared.Config.Interface)
local Ui = require(script.Parent:WaitForChild("UiKit"))
local T, P, Images = Ui.Theme, Interface.Passes, Ui.Images
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
		Ui.Paint(button, "Purple", "COMING SOON", false)
		return
	end
	if (profile.Passes or {})[def.Id] then Ui.Paint(button, "Progress", "OWNED", false); return end
	local info = prices[def.Id]
	Ui.Paint(button, "Purple", if info and info.IsForSale then "R$ " .. tostring(info.PriceInRobux) elseif info then "OFF SALE" else "LOADING...", info ~= nil and info.IsForSale == true)
	if info or loading[def.Id] then return end
	loading[def.Id] = true
	task.spawn(function()
		local ok, result = pcall(function() return Marketplace:GetProductInfoAsync(def.GamePassId, Enum.InfoType.GamePass) end)
		loading[def.Id] = nil
		if ok then prices[def.Id] = result end
		if button.Parent then
			if ok then paintPrice(button, def, profile) else Ui.Paint(button, "Disabled", "PRICE UNAVAILABLE") end
		end
	end)
end

type Card = { Frame: Frame, Arrange: (wide: boolean) -> () }

-- One offer card. Tall: title, icon, two lines, button. Wide: icon left,
-- text right, button bottom right.
local function card(parent: Instance, def, profile): Card
	local look = T.Offers[def.Color]
	local frame = Instance.new("Frame")
	frame.Name = def.Id; frame.BackgroundTransparency = 1
	frame.Parent = parent
	Ui.Corner(frame, 17); Ui.Stroke(frame, 1.5, look.Stroke)
	Ui.Skin(frame, Images[look.Art], look.Fill, 17, if look.Art == "Banner" then look.Fill else nil)
	local rays = Ui.Rays(frame, look.Rays)
	-- Upper case like the boards, but "2x" keeps its small x.
	local title = Ui.Heading(frame, (string.upper(def.DisplayName):gsub("^(%d+)X ", "%1x ")), 19, look.Text)
	title.TextXAlignment = Enum.TextXAlignment.Center; title.TextWrapped = false
	Ui.FitText(title, 12, 22)
	local icon = Ui.Icon(frame, Images[def.Icon], P.Icon)
	local text = Ui.Text(frame, def.Description, 16, look.Text)
	text.TextYAlignment = Enum.TextYAlignment.Top
	local action = Ui.Button(frame, "Purchase", "", function() purchase(def) end, "Purple")
	if def.Action then Ui.Paint(action, "Disabled", string.upper(def.Action)) else paintPrice(action, def, profile) end
	local function arrange(wide: boolean)
		title.Position = UDim2.fromOffset(8, 0); title.Size = UDim2.new(1, -16, 0, 40)
		local limit = title:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint
		limit.MaxTextSize = if wide then 22 else 19
		if wide then
			icon.Size = UDim2.fromOffset(P.WideIcon, P.WideIcon); icon.AnchorPoint = Vector2.zero
			icon.Position = UDim2.fromOffset(10, 49)
			rays.Position = UDim2.fromOffset(7, 7); rays.Size = UDim2.new(1, -14, 1, -14)
			text.Position = UDim2.fromOffset(P.WideIcon + 24, 72); text.Size = UDim2.new(1, -P.WideIcon - 36, 0, 48)
			text.TextXAlignment = Enum.TextXAlignment.Left
			action.AnchorPoint = Vector2.new(1, 1); action.Position = UDim2.new(1, -16, 1, -13)
			action.Size = UDim2.new(0.58, 0, 0, 40)
		else
			icon.Size = UDim2.fromOffset(P.Icon, P.Icon); icon.AnchorPoint = Vector2.new(0.5, 0)
			icon.Position = UDim2.new(0.5, 0, 0, 43)
			rays.Position = UDim2.fromOffset(12, 40); rays.Size = UDim2.new(1, -24, 1, -88)
			text.Position = UDim2.fromOffset(12, 160); text.Size = UDim2.new(1, -24, 0, 44)
			text.TextXAlignment = Enum.TextXAlignment.Center
			action.AnchorPoint = Vector2.new(0.5, 1); action.Position = UDim2.new(0.5, 0, 1, -13)
			action.Size = UDim2.new(1, -30, 0, 40)
		end
	end
	return { Frame = frame, Arrange = arrange }
end

function Shop.Render(parent: Instance, profile)
	local grid = Instance.new("Frame")
	grid.Name = "Offers"; grid.BackgroundTransparency = 1
	grid.LayoutOrder = 1; grid.Size = UDim2.new(1, -4, 0, P.UpperHeight)
	grid.Parent = parent
	local cards: { Card } = {}
	for _, def in Config.List do table.insert(cards, card(grid, def, profile)) end
	table.insert(cards, card(grid, Config.Upcoming, profile))
	local footer = Ui.Text(parent, if Config.CheckoutEnabled then "Permanent upgrades. One purchase per pass." else "Passes will be available soon.", 15)
	footer.Name = "Footer"; footer.LayoutOrder = 2; footer.FontFace = Ui.FontSemi
	footer.TextXAlignment = Enum.TextXAlignment.Center
	footer.Size = UDim2.new(1, -4, 0, 24)
	local note = Ui.Text(parent, "Equipment is sold at the world stalls.", 14, T.TextMuted)
	note.Name = "Note"; note.LayoutOrder = 3; note.FontFace = Ui.FontSemi
	note.TextXAlignment = Enum.TextXAlignment.Center
	note.Size = UDim2.new(1, -4, 0, 20)

	local function arrange()
		local compact = Ui.LocalWidth(grid) < P.CompactWidth
		local gap = P.Gap
		local y = 0
		local index = 1
		local rows = if compact then { 2, 2, 2 } else { P.Upper, #cards - P.Upper }
		for rowIndex, count in rows do
			if index > #cards then break end
			local wide = not compact and rowIndex > 1
			local height = if wide then P.LowerHeight else P.UpperHeight
			for column = 1, count do
				local item = cards[index]
				if not item then break end
				item.Frame.Position = UDim2.new((column - 1) / count, if column == 1 then 0 else gap * (column - 1) / count, 0, y)
				item.Frame.Size = UDim2.new(1 / count, -gap * (count - 1) / count, 0, height)
				item.Arrange(wide)
				index += 1
			end
			y += height + gap
		end
		grid.Size = UDim2.new(1, -4, 0, y - gap)
	end
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(arrange)
	arrange()
end

return Shop
