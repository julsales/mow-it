--!strict
-- Zone gates: expansions are bought at their gate (spec:
-- private-land-progression). Every contract part "ZoneGate" under
-- Workspace/Zones/<ZoneId> gets an "Unlock" prompt near the ground; it is
-- added and wired at runtime, so gates baked into the place or moved by
-- hand work too. The client paints the prompt text for its own player
-- (price, level needed), the server validates the purchase (ShopService).

local Workspace = game:GetService("Workspace")

local Gates = {}

local PROMPT_NAME = "ZoneGatePrompt"
local PROMPT_HEIGHT = 4.5 -- studs above the gate's bottom edge (chest height)

local unlock: ((Player, string) -> ())? = nil
local wired: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- The zone a gate belongs to: the Zones/<ZoneId> ancestor it sits in
-- (directly, or inside that island's Bridge model).
local function zoneIdOf(gate: Instance): string?
	local zones = Workspace:FindFirstChild("Zones")
	local node = gate.Parent
	while node and zones and node.Parent ~= zones do
		node = node.Parent
	end
	return if zones and node then node.Name else nil
end

local function wire(gate: Instance)
	if gate.Name ~= "ZoneGate" or not gate:IsA("BasePart") or wired[gate] or not zoneIdOf(gate) then
		return
	end
	wired[gate] = true

	local anchor = gate:FindFirstChild("PromptAnchor") :: Attachment?
	if not anchor then
		local a = Instance.new("Attachment")
		a.Name = "PromptAnchor"
		a.Position = Vector3.new(0, -gate.Size.Y / 2 + PROMPT_HEIGHT, 0)
		a.Parent = gate
		anchor = a
	end
	local prompt = (anchor :: Attachment):FindFirstChild(PROMPT_NAME) :: ProximityPrompt?
	if not prompt then
		local p = Instance.new("ProximityPrompt")
		p.Name = PROMPT_NAME
		p.ActionText = "Unlock"
		p.KeyboardKeyCode = Enum.KeyCode.E
		p.HoldDuration = 0.4 -- no accidental purchases while walking past
		p.MaxActivationDistance = 12
		p.RequiresLineOfSight = false
		p.Parent = anchor
		prompt = p
	end
	(prompt :: ProximityPrompt).Triggered:Connect(function(player)
		local zoneId = zoneIdOf(gate)
		if unlock and zoneId then
			unlock(player, zoneId)
		end
	end)
end

function Gates.Init(handler: (Player, string) -> ())
	unlock = handler
	for _, d in Workspace:GetDescendants() do
		wire(d)
	end
	Workspace.DescendantAdded:Connect(wire)
end

return Gates
