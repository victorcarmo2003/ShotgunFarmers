local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerAnimations = require(ReplicatedStorage.Shared.Settings.PlayerAnimations)

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
	Reload: string?,
	Draw: string?,
}

local GetAnimations = {}

GetAnimations.Core = function(self): CoreAnimations
	return PlayerAnimations.Core
end

GetAnimations.Viewmodel = function(self, animationSet: string): AnimationSet?
	return PlayerAnimations.Viewmodels[animationSet]
end

GetAnimations.GetCategory = function(self, gunName: string): string
	return PlayerAnimations.PoseCategoryByGun[gunName] or PlayerAnimations.DefaultPoseCategory
end

GetAnimations.CharacterPose = function(self, gunName: string): AnimationSet?
	local category = self:GetCategory(gunName)
	return PlayerAnimations.CharacterPoses[category]
end

return GetAnimations
