--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerAnimations = require(ReplicatedStorage.shared.Character.PlayerAnimations)

export type CoreAnimations = {
	Idle: string,
	Walk: string,
	Run: string,
	CrouchIdle: string,
	CrouchWalk: string,
	Jump: string,
	Fall: string,
	Land: string,
}

export type AnimationSet = {
	Hold: string,
	Aim: string?,
	ShootHip: string?,
	ShootAim: string?,
	Attack: string?,
	Unpin: string?,
	Throw: string?,
	ThrowShort: string?,
	PinIdle: string?,
	AimIn: string?,
	AimOut: string?,
	Discard: string?,
	Reload: string?,
	Draw: string?,
}

const DATA = PlayerAnimations :: {
	Core: CoreAnimations,
	CharacterPoses: { [string]: AnimationSet },
	Viewmodels: { [string]: AnimationSet },
	PoseCategoryByGun: { [string]: string },
	DefaultPoseCategory: string,
	RigMovement: { [string]: string },
}

local GetAnimations = {}

function GetAnimations.Core(): CoreAnimations
	return DATA.Core
end

function GetAnimations.Viewmodel(animationSet: string): AnimationSet?
	return DATA.Viewmodels[animationSet]
end

function GetAnimations.Category(gunName: string): string
	return DATA.PoseCategoryByGun[gunName] or DATA.DefaultPoseCategory
end

function GetAnimations.CharacterPose(gunName: string): AnimationSet?
	return DATA.CharacterPoses[GetAnimations.Category(gunName)]
end

return GetAnimations
