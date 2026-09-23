--modux ignore file
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeLoader = require(ReplicatedStorage.Shared.Utils.KeyframeLoader)

local KEYFRAMES_FOLDER_PATH = { "Assets", "Keyframes" }

local ViewmodelKeyframes = {}

local function getKeyframesFolder(): Folder?
	local current: Instance = ReplicatedStorage
	for _, name in KEYFRAMES_FOLDER_PATH do
		local nextInstance = current:FindFirstChild(name)
		if not nextInstance then
			return nil
		end
		current = nextInstance
	end
	return current :: Folder
end

local function buildJointTable(rig: Model): { [string]: Instance }
	local joints: { [string]: Instance } = {}
	for name, joint in KeyframeLoader.AutoGetMotor6D(rig, "Motor6D") do
		joints[name :: string] = joint :: Instance
	end
	for name, bone in KeyframeLoader.AutoGetMotor6D(rig, "Bone") do
		joints[name :: string] = bone :: Instance
	end
	return joints
end

export type KeyframeNames = {
	Idle: string,
	Aim: string,
	Shoot: string,
}

export type Player = KeyframeLoader.AT
export type Players = {
	Idle: Player?,
	Aim: Player?,
	Shoot: Player?,
}

local function ensureAtLeastTwoFrames(sequence: KeyframeSequence): { any }
	local frames = KeyframeLoader.KeyFrameSequanceToTable(sequence)
	if #frames == 1 then
		local duplicated = table.clone(frames[1])
		duplicated.Time = 1
		table.insert(frames, duplicated)
	end
	return frames
end

function ViewmodelKeyframes.Build(rig: Model, keyframeNames: KeyframeNames): Players
	local folder = getKeyframesFolder()
	if not folder then
		warn("[ViewmodelKeyframes] ReplicatedStorage.Assets.Keyframes não encontrado.")
		return {}
	end

	local oldGroup = rig:FindFirstChild("KeyframeGroup")
	if oldGroup then
		oldGroup:Destroy()
	end

	local joints = buildJointTable(rig)
	local jointNames = {}
	for name in joints do
		table.insert(jointNames, name)
	end
	warn(`[ViewmodelKeyframes DEBUG] {#jointNames} joints coletados: {table.concat(jointNames, ", ")}`)

	local group = KeyframeLoader.CreateModuleGroup()
	group.Name = "KeyframeGroup"
	group.Parent = rig

	local players: Players = {}
	for key, keyframeName in keyframeNames :: { [string]: string } do
		if keyframeName == "" then
			continue
		end
		local sequence = folder:FindFirstChild(keyframeName)
		if sequence and sequence:IsA("KeyframeSequence") then
			local isStaticPose = key == "Idle" or key == "Aim"

			local animationSource: KeyframeSequence | { any } = if isStaticPose
				then ensureAtLeastTwoFrames(sequence :: KeyframeSequence)
				else sequence :: KeyframeSequence

			local player = (KeyframeLoader.new :: any)(joints, animationSource, group) :: Player
			if isStaticPose then
				player.Looped = true
			end
			players[key] = player
			warn(
				`[ViewmodelKeyframes DEBUG] player "{key}" criado a partir de "{keyframeName}" -- Length={player.Length} Looped={player.Looped}`
			)

			for _, keyframe in (sequence :: KeyframeSequence):GetKeyframes() do
				for _, jointName in { "Right Arm", "Left Arm" } do
					local pose = keyframe:FindFirstChild(jointName, true)
					if pose and pose:IsA("Pose") then
						warn(
							`[ViewmodelKeyframes DEBUG] [{key}] Keyframe "{keyframe.Name}" Pose "{jointName}": Weight={pose.Weight} CFrame={pose.CFrame}`
						)
					else
						warn(
							`[ViewmodelKeyframes DEBUG] [{key}] Keyframe "{keyframe.Name}" NÃO tem Pose "{jointName}".`
						)
					end
				end
			end
		else
			warn(
				`[ViewmodelKeyframes DEBUG] KeyframeSequence "{keyframeName}" NÃO encontrada em Assets.Keyframes (key="{key}").`
			)
		end
	end

	return players
end

return ViewmodelKeyframes
