--!strict
-- Puts the equipped tool's 3D model on the player's character while the
-- player holds its Roblox Tool (ToolBackpackService; default hotbar).
--
-- Hand kinds (clipper, scissors, sickle, trimmer) are welded to the right
-- hand. Ground kinds (mowers, riders, tractors) are welded to the
-- HumanoidRootPart at ground level, so they follow the player; riders also
-- lift the player (Humanoid.HipHeight += RideLift) to stand on the deck.
--
-- The model is built on the server and parented to the character, so every
-- player sees everyone's tools. All parts are massless and non-colliding
-- (ToolModels), so they never change how the character moves.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToolModels = require(ReplicatedStorage:WaitForChild("Shared").ToolModels)
local ProfileService = require(script.Parent.ProfileService)

local ToolVisualService = {}

-- Tilt of hand tools relative to the hand. ToolPoses.client.luau (IK)
-- holds the hand forward with the fingers 30 degrees below the horizon,
-- so a negative tilt aims the tool further down at the grass. The long
-- trimmers stay in line with the hand: that already brings the head down
-- to skim the ground (measured in Play; any steeper buries it).
local HAND_TILT: { [string]: number } = {
	clipper = -10,
	scissors = -10,
	sickle = -20,
	trimmer = 0,
}

local GROUND_LIFT = 0.35

local shownToolId: { [Player]: string } = {}
-- Weak keys: a destroyed character never leaves its Humanoid behind here.
local baseHipHeight: { [Humanoid]: number } = setmetatable({}, { __mode = "k" }) :: any

local function clearTool(character: Model)
	local old = character:FindFirstChild("ToolModel")
	if old then
		old:Destroy()
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and baseHipHeight[humanoid] then
		humanoid.HipHeight = baseHipHeight[humanoid]
		baseHipHeight[humanoid] = nil
	end
end

-- Push-handle position that suits this avatar: hands a little below the
-- hip, arms angled slightly forward (ToolModels.Fit, model space).
local function fitFor(character: Model, humanoid: Humanoid, hrp: BasePart): ToolModels.Fit?
	local ground = hrp.Position.Y - hrp.Size.Y / 2 - humanoid.HipHeight
	local upper = character:FindFirstChild("RightUpperArm") :: BasePart?
	local lower = character:FindFirstChild("RightLowerArm") :: BasePart?
	local hand = character:FindFirstChild("RightHand") :: BasePart?
	local shoulderY: number, armLength: number
	if upper and lower and hand then
		shoulderY = (upper.CFrame * CFrame.new(0, upper.Size.Y / 2, 0)).Position.Y
		armLength = upper.Size.Y + lower.Size.Y + hand.Size.Y * 0.5
	else
		local arm = character:FindFirstChild("Right Arm") :: BasePart?
		if not arm then
			return nil
		end
		shoulderY = arm.Position.Y + arm.Size.Y / 2
		armLength = arm.Size.Y * 0.9
		ground -= 2 -- R6: legs hold the HRP up, HipHeight is 0
	end
	-- Arm ~35 deg forward of straight down, slightly bent (90% reach), so
	-- the grip sits around hip height.
	local angle = math.rad(35)
	armLength *= 0.9
	return {
		GripY = shoulderY - ground - armLength * math.cos(angle),
		GripZ = -(armLength * math.sin(angle) + hrp.Size.Z * 0.5),
	}
end

local function attach(character: Model, toolId: string)
	clearTool(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not hrp then
		return
	end

	local model = ToolModels.Build(toolId, fitFor(character, humanoid, hrp))
	local root = model.PrimaryPart :: BasePart
	local kind = model:GetAttribute("Kind") :: string
	local isR6 = humanoid.RigType == Enum.HumanoidRigType.R6

	local weld = Instance.new("Weld")
	weld.Name = "ToolWeld"
	weld.Part1 = root

	if model:GetAttribute("Ground") then
		local lift = (model:GetAttribute("RideLift") :: number?) or 0
		local seat = model:GetAttribute("SeatHeight") :: number?
		if seat then
			-- Seated ride-on: the hips rest on the seat (ToolPoses plays the
			-- sit animation), so HipHeight is the seat's height whatever
			-- the avatar's leg length. R6 legs count as 2 studs.
			-- The machine sits GROUND_LIFT higher, and seated thighs fold
			-- forward under the hips: lift by both so the avatar sits ON the
			-- cushion instead of sinking into it (measured in Play).
			local thigh = character:FindFirstChild("RightUpperLeg") :: BasePart?
			local rest = GROUND_LIFT + (if thigh then thigh.Size.Z / 2 else 0.45)
			baseHipHeight[humanoid] = humanoid.HipHeight
			humanoid.HipHeight = if isR6 then math.max(0, seat - 2 + rest) else seat + rest
		elseif lift > 0 then
			-- Standing on a deck: + GROUND_LIFT, or the feet sink into it.
			baseHipHeight[humanoid] = humanoid.HipHeight
			humanoid.HipHeight += lift + GROUND_LIFT
		end
		-- R6 rigs report HipHeight 0; their legs (2 studs) hold the HRP up.
		local legs = if isR6 then 2 else 0
		local down = humanoid.HipHeight + hrp.Size.Y / 2 + legs
		weld.Part0 = hrp
		-- Lift a little so wheels sit on top of the Terrain grass blades
		-- instead of sinking into them.
		weld.C0 = CFrame.new(0, -down + GROUND_LIFT, 0)
	else
		local hand = (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
		if not hand then
			model:Destroy()
			return
		end
		local grip = hand:FindFirstChild("RightGripAttachment") :: Attachment?
		-- Position only: the attachment's own rotation differs between rigs.
		local gripCFrame = if grip then CFrame.new(grip.Position) else CFrame.new(0, -hand.Size.Y / 2, 0)
		-- The hand hangs along -Y; the model points along -Z. Rotate -90 deg
		-- about X so the model points down the arm, then tilt it.
		local tilt = math.rad(HAND_TILT[kind] or -15)
		weld.Part0 = hand
		weld.C0 = gripCFrame * CFrame.Angles(-math.rad(90) + tilt, 0, 0)
	end

	weld.Parent = root
	model.Parent = character
end

local function refresh(player: Player)
	local profile = ProfileService.Get(player)
	local character = player.Character
	if not profile or not character then
		return
	end
	if not character:FindFirstChildOfClass("Tool") then
		-- Put away from the hotbar: nothing in the hands.
		shownToolId[player] = nil
		clearTool(character)
		return
	end
	if shownToolId[player] == profile.EquippedToolId and character:FindFirstChild("ToolModel") then
		return
	end
	shownToolId[player] = profile.EquippedToolId
	attach(character, profile.EquippedToolId)
end

local function onCharacter(player: Player, character: Model)
	shownToolId[player] = nil
	-- Wait for the rig so the hand/HRP exist and HipHeight is final.
	character:WaitForChild("HumanoidRootPart", 10)
	character:WaitForChild("Humanoid", 10)
	task.wait()
	if player.Character == character then
		refresh(player)
	end
end

ToolVisualService.Refresh = refresh

function ToolVisualService.Init()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		shownToolId[player] = nil
	end)
	ProfileService.OnChanged(function(player)
		task.spawn(refresh, player)
	end)
	-- Each cut request stamps the held model, so every client plays the
	-- blades' open-close (ToolAnimations.client). Visual only: the cut
	-- itself is validated by EconomyService.
	local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
	local cutRequest = remotes:WaitForChild("CutRequest") :: RemoteEvent
	cutRequest.OnServerEvent:Connect(function(player)
		local character = player.Character
		local model = character and character:FindFirstChild("ToolModel")
		if model then
			model:SetAttribute("SwingAt", workspace:GetServerTimeNow())
		end
	end)
end

return ToolVisualService
