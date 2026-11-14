--!strict
-- The tool seller on every island: a farmer standing behind a small
-- market stand, off to the side of the island. One builder for all
-- islands; each island passes its own farmer name and outfit color.
--
-- Contract (docs/EDITING.md): the model is named "FarmerStand" and sits in
-- Workspace/Zones/<ZoneId>; its counter carries the "OpenShopPrompt"
-- (opens the Shop panel), the tools hang on ShopDisplay plaques
-- (ShopItem + ToolId + ShopItemPrompt, wired by ShopService/ShopDisplay)
-- and the farmer is the "Npc" model quests point at (QuestWorld).
--
-- Frame `cf`: origin on the ground at the stand, +Z = the front (where
-- players walk up to the counter).

local Props = require(script.Parent.Props)
local ShopDisplay = require(script.Parent.ShopDisplay)

local FarmerStand = {}

FarmerStand.Radius = 18 -- footprint kept clear of lawns and props (stand, tool board, mowers)

-- "Browse all" prompt on a counter: opens the Shop panel client-side.
local function addCounterPrompt(counter: BasePart?)
	if not counter then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenShopPrompt"
	prompt.ObjectText = "Tools"
	prompt.ActionText = "Browse all"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
end

function FarmerStand.Build(parent: Instance, cf: CFrame, toolIds: { string }, farmer: string, outfit: Color3): Model
	local stand = Props.shop(parent, cf, 0, 0, outfit, "TOOLS")
	stand.Name = "FarmerStand"
	addCounterPrompt(stand:FindFirstChild("Counter") :: BasePart?)
	-- The farmer behind the counter, facing the customers.
	Props.npc(stand, cf * CFrame.new(0, 0, -0.4) * CFrame.Angles(0, math.pi, 0), farmer .. " · Tools", outfit)
	-- Hand tools hang on a pegboard on legs beside the stand; mowers park in
	-- a row on the other side. Nothing in front of the counter.
	local boardX, boardW, boardH, boardLift = -12.5, 9, 5.2, 1.2
	local hand = ShopDisplay.Split(toolIds)
	if #hand > 0 then
		for _, dx in { -boardW / 2 + 0.3, boardW / 2 - 0.3 } do
			Props.box("BoardLeg", stand, cf, Vector3.new(0.5, boardLift + boardH, 0.5), boardX + dx, -0.1, Props.Colors.DarkWood, Enum.Material.Wood)
		end
	end
	ShopDisplay.Build(stand, cf, toolIds, {
		BoardWidth = boardW,
		BoardHeight = boardH,
		BoardLift = boardLift,
		BoardOffsetX = boardX,
		ParkOffsetX = 8.5,
		ParkDistance = 1,
	})
	return stand
end

return FarmerStand
