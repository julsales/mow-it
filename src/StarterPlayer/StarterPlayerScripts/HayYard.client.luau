--!strict
-- The hay yard, client side: everything you SEE of selling (the server
-- owns the state, HayService).
--   * the baler works while it has grass: flywheel, rattling body, the
--     press stomping, exhaust puffs, the grass heap sinking in the hopper;
--   * every new bale slides out of the chamber and hops onto the stack;
--   * click a bale to sell it: it hops onto the elevator, rides up and
--     drops into the silo, coins pop up;
--   * customers walk up to the silo's counter and carry bales away.
-- Bales and the machine state come from the profile (ClientState);
-- customers and tips from HayCustomer / HayTip.
--
-- The yard is found by its contract names (Workspace/Zones/…/HayYard with
-- Baler, BaleStack, Silo), never by position: drag the pieces anywhere.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.HayYard)
local Colors = require(Shared.Config.Interface).Colors
local Format = require(Shared.Format)
local GrassBag = require(Shared.GrassBag)
local Hay = require(Shared.Hay)

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local Bales = require(script.Parent:WaitForChild("HayBales"))
local Customers = require(script.Parent:WaitForChild("HayCustomers"))
local Rigs = require(script.Parent:WaitForChild("HayRigs"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local hayAction = remotes:WaitForChild("HayAction") :: RemoteEvent

local ACTIVE_DISTANCE = 260 -- the yard only animates when the player is this close
local BELT_SPEED = 5.5
local GOLD = Color3.fromRGB(255, 214, 90)

local baleMarkers = Config.Pieces.Baler.Markers
local siloMarkers = Config.Pieces.Silo.Markers
local beltVector = siloMarkers.ElevatorTop - siloMarkers.ElevatorFoot
local beltTilt = CFrame.Angles(0, 0, math.atan2(beltVector.Y, beltVector.X))
local beltUp = Vector3.new(-beltVector.Y, beltVector.X, 0).Unit * (Config.Stack.BaleHeight / 2)

-- Local things live here (bales, effects), so the baked yard stays untouched.
local folder = Instance.new("Folder")
folder.Name = "HayYardLocal"
folder.Parent = Workspace

-- Small helpers -------------------------------------------------------------------

local function anchor(at: Vector3): Part
	local part = Instance.new("Part")
	part.Name = "Anchor"
	part.Size = Vector3.one * 0.2
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Position = at
	part.Parent = folder
	return part
end

-- A floating label over something (status of the baler, the stack, the silo).
local function tag(at: Vector3, width: number): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HayTag"
	gui.Size = UDim2.fromOffset(width, 34)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.Adornee = anchor(at)
	gui.ResetOnSpawn = false
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Colors.Cream
	text.TextColor3 = Colors.Ink
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = text
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Colors.Ink
	stroke.Thickness = 2
	stroke.Parent = text
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingBottom = UDim.new(0, 5)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = text
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui, text
end

-- "+25" rising and fading where something was sold.
local function popup(at: Vector3, message: string, color: Color3)
	local host = anchor(at)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(190, 46)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Adornee = host
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = color
	text.Text = message
	text.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Colors.Ink
	stroke.Thickness = 2.5
	stroke.Parent = text
	gui.Parent = host
	task.spawn(function()
		Bales.Animate(1.1, function(a)
			gui.StudsOffsetWorldSpace = Vector3.new(0, 1 + 3.2 * (1 - (1 - a) ^ 2), 0)
			local fade = math.clamp((a - 0.6) / 0.4, 0, 1)
			text.TextTransparency = fade
			stroke.Transparency = fade
		end)
		host:Destroy()
	end)
end

local function puffs(parent: Instance, color: Color3, size: number, speed: number, up: Vector3): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.35), NumberSequenceKeypoint.new(0.5, size), NumberSequenceKeypoint.new(1, size * 1.3) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.7, 0.55), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.7, 1.3)
	emitter.Speed = NumberRange.new(speed * 0.6, speed)
	emitter.SpreadAngle = Vector2.new(14, 14)
	emitter.Acceleration = up
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.LightInfluence = 1
	emitter.Rate = 0
	emitter.Parent = parent
	return emitter
end

-- The view of one yard ---------------------------------------------------------------

type View = {
	Yard: Model,
	Baler: Model,
	Pallet: Model,
	Silo: Model,
	BalerRigs: Rigs.Player,
	SiloRigs: Rigs.Player,
	Stack: Bales.StackT,
	Entries: { [number]: Bales.Entry },
	Sold: { [number]: Vector3 }, -- where a just-sold bale was (for the coin popup)
	Lamp: BasePart?,
	Smoke: ParticleEmitter,
	Dust: ParticleEmitter,
	Chaff: ParticleEmitter,
	BalerTag: TextLabel,
	BalerGui: BillboardGui,
	StackTag: TextLabel,
	StackGui: BillboardGui,
	SiloTag: TextLabel,
	Power: number, -- 0..1, the baler spinning up and down
	Heap: number,
	Hatch: number,
	Press: number, -- phase of the press stroke
	Clock: number,
	OnBelt: number,
	NearHatch: number,
	Ejecting: boolean,
	Highlight: Highlight,
	Connection: RBXScriptConnection?,
}

local view: View? = nil

local function at(model: Model, point: Vector3): Vector3
	return (model:GetPivot() * CFrame.new(point)).Position
end

local function createView(yard: Model, baler: Model, pallet: Model, silo: Model): View
	local exhaust = anchor(at(baler, baleMarkers.Exhaust))
	local mouth = anchor(at(baler, baleMarkers.Tray))
	local hopper = anchor(at(baler, baleMarkers.Hopper))
	local balerGui, balerTag = tag(at(baler, baleMarkers.Hopper + Vector3.new(0, 3.2, 0)), 250)
	local stackGui, stackTag = tag(at(pallet, Vector3.new(0, 8.2, 0)), 210)
	local _, siloTag = tag(at(silo, siloMarkers.Counter + Vector3.new(0, 2.6, 1.2)), 150)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = GOLD
	highlight.FillTransparency = 0.65
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.Parent = folder
	local chaff = puffs(hopper, Color3.fromRGB(140, 196, 90), 0.5, 7, Vector3.new(0, -18, 0))
	chaff.SpreadAngle = Vector2.new(40, 40)
	chaff.Lifetime = NumberRange.new(0.4, 0.7)
	local lamp = baler:FindFirstChild("Lamp")
	return {
		Yard = yard,
		Baler = baler,
		Pallet = pallet,
		Silo = silo,
		BalerRigs = Rigs.new(baler, Config.Pieces.Baler.Rigs),
		SiloRigs = Rigs.new(silo, Config.Pieces.Silo.Rigs),
		Stack = Bales.Stack.new(pallet),
		Entries = {},
		Sold = {},
		Lamp = if lamp and lamp:IsA("BasePart") then lamp else nil,
		Smoke = puffs(exhaust, Color3.fromRGB(236, 232, 224), 1.3, 5, Vector3.new(0.6, 3, 0)),
		Dust = puffs(mouth, Color3.fromRGB(240, 226, 170), 1.1, 3, Vector3.new(0, 1, 0)),
		Chaff = chaff,
		BalerTag = balerTag,
		BalerGui = balerGui,
		StackTag = stackTag,
		StackGui = stackGui,
		SiloTag = siloTag,
		Power = 0,
		Heap = 0,
		Hatch = 0,
		Press = 0,
		Clock = 0,
		OnBelt = 0,
		NearHatch = 0,
		Ejecting = false,
		Highlight = highlight,
		Connection = nil,
	}
end

-- Bales --------------------------------------------------------------------------------

-- Out of the chamber onto the tray, then a hop onto the stack.
local function eject(v: View, entry: Bales.Entry)
	while v.Ejecting do
		task.wait()
	end
	v.Ejecting = true
	local model = entry.Model
	local pivot = v.Baler:GetPivot()
	local inside, tray = pivot * CFrame.new(baleMarkers.Mouth), pivot * CFrame.new(baleMarkers.Tray)
	model:ScaleTo(0.6)
	model:PivotTo(inside)
	v.Dust:Emit(6)
	task.spawn(Bales.Pop, model, 0.3)
	Bales.Slide(model, inside, tray, 0.4)
	task.wait(0.12)
	v.Ejecting = false
	Bales.Hop(model, tray, v.Stack:SlotCFrame(entry, v.Stack:LayerOf(entry)), 0.45, 2.4, 1)
end

local function addBale(v: View, bale: Hay.Bale, instant: boolean)
	local model, hit = Bales.Make(bale.Golden, folder)
	local entry: Bales.Entry = { Id = bale.Id, Model = model, Hit = hit, Golden = bale.Golden, Column = 1, Busy = 0 }
	v.Entries[bale.Id] = entry
	local slot = v.Stack:Add(entry)
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = Config.SellDistance
	click.MouseClick:Connect(function()
		hayAction:FireServer("Sell", bale.Id)
	end)
	click.MouseHoverEnter:Connect(function()
		v.Highlight.Adornee = model
		v.Highlight.Enabled = true
	end)
	click.MouseHoverLeave:Connect(function()
		if v.Highlight.Adornee == model then
			v.Highlight.Enabled = false
		end
	end)
	click.Parent = hit
	if instant then
		model:PivotTo(slot)
		return
	end
	entry.Busy += 1
	task.spawn(function()
		eject(v, entry)
		entry.Busy -= 1
	end)
end

-- Sold: off the stack, onto the elevator, up the belt and into the silo.
local function sendToSilo(v: View, entry: Bales.Entry)
	local model = entry.Model
	local click = entry.Hit:FindFirstChildOfClass("ClickDetector")
	if click then
		click:Destroy()
	end
	if v.Highlight.Adornee == model then
		v.Highlight.Enabled = false
	end
	v.Sold[entry.Id] = model:GetPivot().Position
	task.delay(2, function()
		v.Sold[entry.Id] = nil
	end)
	task.spawn(function()
		while entry.Busy > 0 do
			task.wait()
		end
		v.Stack:Remove(entry)
		local pivot = v.Silo:GetPivot()
		local foot = pivot * CFrame.new(siloMarkers.ElevatorFoot + beltUp + beltVector.Unit * 1.4) * beltTilt
		local top = pivot * CFrame.new(siloMarkers.ElevatorTop + beltUp - beltVector.Unit * 0.6) * beltTilt
		local inside = pivot * CFrame.new(siloMarkers.Inside)
		v.OnBelt += 1
		Bales.Hop(model, model:GetPivot(), foot, 0.5, 3.4, 1)
		local seconds = (top.Position - foot.Position).Magnitude / BELT_SPEED
		local opened = false
		Bales.Animate(seconds, function(a)
			model:PivotTo(foot:Lerp(top, a))
			if a > 0.55 and not opened then
				opened = true
				v.NearHatch += 1
			end
		end)
		task.spawn(Bales.Shrink, model, 0.22)
		Bales.Slide(model, top, inside, 0.22)
		model:Destroy()
		v.OnBelt -= 1
		task.wait(0.25)
		v.NearHatch -= 1
	end)
end

local function sync(v: View, profile: any, instant: boolean)
	local state = Hay.State(profile)
	local seen: { [number]: boolean } = {}
	for _, bale in state.Bales do
		seen[bale.Id] = true
		if not v.Entries[bale.Id] then
			addBale(v, bale, instant)
		end
	end
	for id, entry in v.Entries do
		if not seen[id] then
			v.Entries[id] = nil
			sendToSilo(v, entry)
		end
	end
	-- labels
	local units, count = state.Units, #state.Bales
	if units > 0 and Hay.IsStackFull(profile) then
		v.BalerTag.Text = "Stack full! Sell some bales"
	elseif units > 0 then
		v.BalerTag.Text = ("Baling… %s grass left"):format(Format.Number(units))
	elseif GrassBag.Total(profile) > 0 then
		v.BalerTag.Text = "Step up to load your grass"
	end
	v.BalerGui.Enabled = units > 0 or GrassBag.Total(profile) > 0
	v.StackTag.Text = "Click a bale to sell it"
	v.StackGui.Enabled = count > 0
	v.SiloTag.Text = ("Stock: %d"):format(state.Stock)
end

-- The machines, every frame -----------------------------------------------------------------

local function approach(value: number, goal: number, step: number): number
	return if value < goal then math.min(value + step, goal) else math.max(value - step, goal)
end

local function step(v: View, profile: any, dt: number)
	v.Clock += dt
	local t = v.Clock
	local working = Hay.IsWorking(profile)
	local full = Hay.State(profile).Units > 0 and Hay.IsStackFull(profile)
	v.Power = approach(v.Power, if working then 1 else 0, dt * 1.6)
	local power = v.Power

	-- the press: slow rise, hard stomp, twice per bale
	local stroke = 0
	local stomped = false
	if power > 0.4 then
		local period = Hay.Level(profile).BaleSeconds / 2
		local before = v.Press
		v.Press = (v.Press + dt / period) % 1
		local p = v.Press
		stroke = if p < 0.72 then (p / 0.72) ^ 0.7 elseif p < 0.82 then 1 - (p - 0.72) / 0.1 else 0
		stomped = before < 0.82 and p >= 0.82
	else
		v.Press = 0
	end
	if stomped then
		v.Smoke:Emit(3)
		v.Chaff:Emit(4)
	end
	local kick = if power > 0.4 and v.Press >= 0.82 then (1 - (v.Press - 0.82) / 0.18) else 0

	local ratio = Hay.HopperRatio(profile)
	local heap = if Hay.State(profile).Units > 0 then math.max(ratio, 0.3) else 0
	v.Heap = approach(v.Heap, heap, dt * 0.9)

	local rigs = v.BalerRigs
	rigs:Set("Shake", power * (0.55 + 1.6 * kick))
	rigs:Set("Flywheel", 10 * power)
	rigs:Set("Plunger", stroke * power)
	rigs:Set("Cap", power * math.max(0, math.sin(t * 13)) ^ 2 + kick * 0.6)
	rigs:Set("Needle", 0.12 + power * (0.62 + 0.1 * math.sin(t * 7)) + kick * 0.2)
	rigs:Set("Heap", 1 - v.Heap)
	rigs:Step(dt)
	v.Smoke.Rate = 5 * power

	if v.Lamp then
		local lamp = Config.Lamp
		local blink = math.sin(t * 9) > 0
		if full then
			v.Lamp.Color = if blink then lamp.Full else lamp.Idle
			v.Lamp.Material = if blink then Enum.Material.Neon else Enum.Material.SmoothPlastic
		elseif working then
			v.Lamp.Color = lamp.Working
			v.Lamp.Material = Enum.Material.Neon
		else
			v.Lamp.Color = lamp.Idle
			v.Lamp.Material = Enum.Material.SmoothPlastic
		end
	end

	v.Hatch = approach(v.Hatch, if v.NearHatch > 0 then 1 else 0, dt * 5)
	local silo = v.SiloRigs
	silo:Set("Belt", if v.OnBelt > 0 then BELT_SPEED else 0)
	silo:Set("Hatch", v.Hatch)
	silo:Set("Vane", 0.7 + 0.5 * math.sin(t * 0.37))
	silo:Step(dt)
end

-- Grass flying from the player into the hopper when a load is handed in.
local function throwGrass(v: View, units: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local target = at(v.Baler, baleMarkers.Hopper)
	if (root.Position - target).Magnitude > 60 then
		return -- handed in at a far drop-off pad
	end
	local color = Config.Paint.Grass.Color
	for i = 1, math.clamp(math.ceil(units / 2), 5, 16) do
		task.delay((i - 1) * 0.045, function()
			local clump = Instance.new("Part")
			clump.Name = "Grass"
			clump.Size = Vector3.new(0.55, 0.3, 0.45) * (0.8 + (i % 3) * 0.2)
			clump.Color = color:Lerp(Color3.new(1, 1, 0.6), (i % 4) * 0.06)
			clump.Material = Enum.Material.SmoothPlastic
			clump.Anchored = true
			clump.CanCollide = false
			clump.CanQuery = false
			clump.CanTouch = false
			clump.CastShadow = false
			clump.Parent = folder
			local from = root.Position + Vector3.new((i % 3 - 1) * 0.5, 0.6, 0)
			local to = target + Vector3.new(((i * 7) % 5 - 2) * 0.3, 0, ((i * 3) % 5 - 2) * 0.3)
			local peak = math.max(from.Y, to.Y) + 2.5
			Bales.Animate(0.42, function(a)
				local y = (1 - a) * from.Y + a * to.Y + 4 * a * (1 - a) * (peak - (from.Y + to.Y) / 2)
				local flat = from:Lerp(to, a)
				clump.CFrame = CFrame.new(flat.X, y, flat.Z) * CFrame.Angles(a * 9 + i, a * 7, i)
			end)
			clump:Destroy()
		end)
	end
end

-- Wiring ---------------------------------------------------------------------------------------

local function findYard(): (Model?, Model?, Model?, Model?)
	local zones = Workspace:FindFirstChild("Zones")
	local yard = zones and zones:FindFirstChild("HayYard", true)
	if not yard or not yard:IsA("Model") then
		return nil
	end
	local baler, pallet, silo = yard:FindFirstChild("Baler"), yard:FindFirstChild("BaleStack"), yard:FindFirstChild("Silo")
	if baler and pallet and silo and baler:IsA("Model") and pallet:IsA("Model") and silo:IsA("Model") then
		return yard, baler, pallet, silo
	end
	return nil
end

local function dropView()
	local v = view
	if v then
		view = nil
		v.BalerRigs:Destroy()
		v.SiloRigs:Destroy()
		if v.Connection then
			v.Connection:Disconnect()
		end
		folder:ClearAllChildren()
		for _, gui in (player:WaitForChild("PlayerGui")):GetChildren() do
			if gui.Name == "HayTag" then
				gui:Destroy()
			end
		end
	end
end

-- Look for the yard now and then (it may stream in or be rebuilt).
task.spawn(function()
	while true do
		if not view then
			local yard, baler, pallet, silo = findYard()
			if yard and baler and pallet and silo then
				local v = createView(yard, baler, pallet, silo)
				v.Connection = yard.AncestryChanged:Connect(function(_, parent)
					if not parent then
						dropView()
					end
				end)
				view = v
				local profile = ClientState.Get()
				if profile then
					sync(v, profile, true)
				end
			end
		end
		task.wait(1)
	end
end)

ClientState.Changed:Connect(function(profile)
	if view then
		sync(view, profile, false)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local v, profile = view, ClientState.Get()
	local camera = Workspace.CurrentCamera
	if v and profile and camera and (camera.CFrame.Position - v.Baler:GetPivot().Position).Magnitude < ACTIVE_DISTANCE then
		step(v, profile, dt)
	end
end);

(remotes:WaitForChild("HayLoaded") :: RemoteEvent).OnClientEvent:Connect(function(units: number)
	if view then
		throwGrass(view, units)
	end
end);

(remotes:WaitForChild("SellFeedback") :: RemoteEvent).OnClientEvent:Connect(function(earned: number, baleId: number?)
	local v = view
	local where = v and baleId and v.Sold[baleId]
	if where then
		popup(where, "+" .. Format.Number(earned), GOLD)
	end
end);

(remotes:WaitForChild("HayCustomer") :: RemoteEvent).OnClientEvent:Connect(function(bales: number, walkSeconds: number)
	local v = view
	local spawn = v and v.Yard:FindFirstChild("CustomerSpawn")
	if v and spawn and spawn:IsA("BasePart") then
		Customers.Visit(v.Silo, spawn.Position, bales, walkSeconds, function() end)
	end
end);

(remotes:WaitForChild("HayTip") :: RemoteEvent).OnClientEvent:Connect(function(tip: number)
	if view then
		popup(at(view.Silo, siloMarkers.Counter + Vector3.new(0, 2, 1.5)), ("+%s tip"):format(Format.Number(tip)), Colors.Leaf)
	end
end)
