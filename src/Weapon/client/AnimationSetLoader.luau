--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetAnimations = require(ReplicatedStorage.shared.Character.GetAnimations)

export type Role =
	"Hold"
	| "Aim"
	| "ShootHip"
	| "ShootAim"
	| "Draw"
	| "Reload"
	| "Unpin"
	| "Throw"
	| "ThrowShort"
	| "PinIdle"
	| "AimIn"
	| "AimOut"
	| "Discard"
	| "Attack"

export type TrackSet = { [Role]: AnimationTrack? }

const PRIORITY_BY_ROLE: { [Role]: Enum.AnimationPriority } = {
	Hold = Enum.AnimationPriority.Action,
	Aim = Enum.AnimationPriority.Action2,
	ShootHip = Enum.AnimationPriority.Action3,
	ShootAim = Enum.AnimationPriority.Action3,
	Draw = Enum.AnimationPriority.Action4,
	Reload = Enum.AnimationPriority.Action4,
	Unpin = Enum.AnimationPriority.Action4,
	Throw = Enum.AnimationPriority.Action4,
	ThrowShort = Enum.AnimationPriority.Action4,
	PinIdle = Enum.AnimationPriority.Action2,
	AimIn = Enum.AnimationPriority.Action4,
	AimOut = Enum.AnimationPriority.Action4,
	Discard = Enum.AnimationPriority.Action4,
	Attack = Enum.AnimationPriority.Action4,
}

const LOOPED_BY_ROLE: { [Role]: boolean } = {
	Hold = true,
	Aim = true,
	ShootHip = false,
	ShootAim = false,
	Draw = false,
	Reload = false,
	Unpin = false,
	Throw = false,
	ThrowShort = false,
	PinIdle = true,
	AimIn = false,
	AimOut = false,
	Discard = false,
	Attack = false,
}

local function idsOf(set: GetAnimations.AnimationSet): { [Role]: string? }
	return {
		Hold = set.Hold,
		Aim = set.Aim,
		ShootHip = set.ShootHip,
		ShootAim = set.ShootAim,
		Draw = set.Draw,
		Reload = set.Reload,
		Unpin = set.Unpin,
		Throw = set.Throw,
		ThrowShort = set.ThrowShort,
		PinIdle = set.PinIdle,
		AimIn = set.AimIn,
		AimOut = set.AimOut,
		Discard = set.Discard,
		Attack = set.Attack,
	}
end

local function loadTrack(animator: Animator, role: Role, animationId: string?): AnimationTrack?
	if not animationId or animationId == "" then
		return nil
	end

	const animation = Instance.new("Animation")
	animation.AnimationId = animationId
	const track = animator:LoadAnimation(animation)
	animation:Destroy()

	track.Looped = LOOPED_BY_ROLE[role]
	track.Priority = PRIORITY_BY_ROLE[role]

	return track
end

local AnimationSetLoader = {}

function AnimationSetLoader.Load(animator: Animator?, set: GetAnimations.AnimationSet?): TrackSet
	const tracks: TrackSet = {}
	if not animator or not set then
		return tracks
	end

	for role, animationId in idsOf(set) do
		tracks[role] = loadTrack(animator, role, animationId)
	end

	return tracks
end

function AnimationSetLoader.Unload(tracks: TrackSet?)
	if not tracks then
		return
	end

	for _, track in tracks do
		if track then
			track:Stop(0)
			track:Destroy()
		end
	end
end

return AnimationSetLoader
