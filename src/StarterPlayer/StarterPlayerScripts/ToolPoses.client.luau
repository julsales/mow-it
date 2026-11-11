--!strict
-- Holding poses, with no animation assets: every client poses every
-- character that carries a ToolModel, so everyone sees it.
--   * Push/reel mowers: both hands on the handle (GripL/GripR attachments).
--   * Riders/tractors: both hands on the steering wheel.
--   * Hand tools: right arm held forward and down; the local player's arm
--     chops down on each swing (CutFeedback).
-- R15 uses IKControl (arms reach the targets, walking animation keeps the
-- legs). R6 has no IK chain, so its shoulders are angled via Motor6D C0.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Hand tools: where the right hand rests, relative to the HumanoidRootPart.
local HOLD_OFFSET = Vector3.new(0.9, -0.4, -1.7)
local SWING_OFFSET = Vector3.new(0.3, -1.3, -1.5)

type Pose = { Cleanup: { Instance }, Restore: { [Motor6D]: CFrame }, Target: Attachment? }
local poses: { [Model]: Pose } = {}

local function clearPose(character: Model)
	local pose = poses[character]
	if not pose then
		return
	end
	poses[character] = nil
	for _, instance in pose.Cleanup do
		instance:Destroy()
	end
	for motor, c0 in pose.Restore do
		if motor.Parent then
			motor.C0 = c0
		end
	end
end

local function ik(humanoid: Humanoid, character: Model, side: string, target: Attachment, pose: Pose, matchRotation: boolean?)
	local upper = character:FindFirstChild(side .. "UpperArm")
	local hand = character:FindFirstChild(side .. "Hand")
	if not upper or not hand then
		return
	end
	local control = Instance.new("IKControl")
	control.Name = "ToolPose" .. side
	-- Transform also turns the hand to the grip's orientation (palm on the
	-- bar); Position only moves it.
	control.Type = if matchRotation then Enum.IKControlType.Transform else Enum.IKControlType.Position
	control.ChainRoot = upper
	control.EndEffector = hand
	control.Target = target
	control.Weight = 1
	control.SmoothTime = 0.05
	control.Parent = humanoid
	table.insert(pose.Cleanup, control)
end

local function r6Shoulder(character: Model, name: string, angle: number, pose: Pose)
	local torso = character:FindFirstChild("Torso")
	local motor = torso and torso:FindFirstChild(name) :: Motor6D?
	if motor then
		pose.Restore[motor] = motor.C0
		-- R6 shoulders hinge about their local Z; this raises the arm forward.
		motor.C0 = motor.C0 * CFrame.Angles(0, 0, angle)
	end
end

local function applyPose(character: Model)
	clearPose(character)
	local model = character:FindFirstChild("ToolModel")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not model or not humanoid or not hrp then
		return
	end
	local pose: Pose = { Cleanup = {}, Restore = {}, Target = nil }
	poses[character] = pose
	local r15 = humanoid.RigType == Enum.HumanoidRigType.R15
	local gripL = model:FindFirstChild("GripL", true) :: Attachment?
	local gripR = model:FindFirstChild("GripR", true) :: Attachment?

	if gripL and gripR then
		-- Two-handed: mower handle or steering wheel.
		if r15 then
			ik(humanoid, character, "Left", gripL, pose, true)
			ik(humanoid, character, "Right", gripR, pose, true)
		else
			r6Shoulder(character, "Left Shoulder", -math.rad(70), pose)
			r6Shoulder(character, "Right Shoulder", math.rad(70), pose)
		end
	elseif model:GetAttribute("Ground") ~= true then
		-- One-handed tool: right arm forward.
		if r15 then
			local target = Instance.new("Attachment")
			target.Name = "ToolPoseTarget"
			target.Position = HOLD_OFFSET
			target.Parent = hrp
			table.insert(pose.Cleanup, target)
			pose.Target = target
			ik(humanoid, character, "Right", target, pose)
		else
			r6Shoulder(character, "Right Shoulder", math.rad(55), pose)
		end
	end
end

local function watchCharacter(character: Model)
	local function onChild(child: Instance)
		if child.Name == "ToolModel" then
			-- The model's parts replicate a moment after the model itself;
			-- wait (up to ~1 s) for the grips of two-handed tools.
			task.spawn(function()
				for _ = 1, 60 do
					if child.Parent ~= character then
						return
					end
					if child:GetAttribute("Ground") ~= true or child:FindFirstChild("GripR", true) then
						break
					end
					task.wait()
				end
				if child.Parent == character then
					applyPose(character)
				end
			end)
		end
	end
	character.ChildAdded:Connect(onChild)
	character.ChildRemoved:Connect(function(child)
		if child.Name == "ToolModel" and not character:FindFirstChild("ToolModel") then
			clearPose(character)
		end
	end)
	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			clearPose(character)
		end
	end)
	if character:FindFirstChild("ToolModel") then
		onChild(character:FindFirstChild("ToolModel") :: Instance)
	end
end

local function watchPlayer(other: Player)
	other.CharacterAdded:Connect(watchCharacter)
	if other.Character then
		watchCharacter(other.Character)
	end
end
Players.PlayerAdded:Connect(watchPlayer)
for _, other in Players:GetPlayers() do
	watchPlayer(other)
end

-- Local swing: the hand chops down and comes back.
local DOWN = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local UP = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local function swing()
	local character = player.Character
	local pose = character and poses[character]
	local target = pose and pose.Target
	if not target then
		return
	end
	local down = TweenService:Create(target, DOWN, { Position = SWING_OFFSET })
	down.Completed:Once(function()
		TweenService:Create(target, UP, { Position = HOLD_OFFSET }):Play()
	end)
	down:Play()
end

(remotes:WaitForChild("CutFeedback") :: RemoteEvent).OnClientEvent:Connect(function(_stored, _full, hit)
	if hit ~= nil then
		swing()
	end
end)
