--!strict
-- Puts the equipped tool's 3D model on the player's character.
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

-- Tilt of hand tools relative to the forearm. The arm is held forward and
-- down by ToolPoses.client.luau (IK), so a negative tilt aims the tool
-- further down at the grass; the trimmer is steepest so its head reaches.
local HAND_TILT: { [string]: number } = {
	clipper = -10,
	scissors = -10,
	sickle = -20,
	trimmer = -35,
}

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
	-- Arm ~25 deg forward of straight down from the shoulder.
	local angle = math.rad(25)
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
		if lift > 0 then
			baseHipHeight[humanoid] = humanoid.HipHeight
			humanoid.HipHeight += lift
		end
		-- R6 rigs report HipHeight 0; their legs (2 studs) hold the HRP up.
		local legs = if isR6 then 2 else 0
		local down = humanoid.HipHeight + hrp.Size.Y / 2 + legs
		weld.Part0 = hrp
		weld.C0 = CFrame.new(0, -down, 0)
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
end

return ToolVisualService
