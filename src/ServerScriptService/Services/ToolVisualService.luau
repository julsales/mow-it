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

-- Forward tilt of hand tools so they point at the grass, not the sky.
local HAND_TILT: { [string]: number } = {
	clipper = 70,
	scissors = 70,
	sickle = 60,
	trimmer = 55,
}

local shownToolId: { [Player]: string } = {}
local baseHipHeight: { [Humanoid]: number } = {}

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

local function attach(character: Model, toolId: string)
	clearTool(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not hrp then
		return
	end

	local model = ToolModels.Build(toolId)
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
		-- about X so the model points down the arm, then tilt it forward.
		local tilt = math.rad(HAND_TILT[kind] or 60)
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
