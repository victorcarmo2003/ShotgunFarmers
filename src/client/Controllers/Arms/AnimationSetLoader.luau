--modux ignore file
--!strict

local AnimationSetLoader = {}

export type TrackSet = { [string]: AnimationTrack? }

local PRIORITY_BY_ROLE: { [string]: Enum.AnimationPriority } = {
	Hold = Enum.AnimationPriority.Action,
	Aim = Enum.AnimationPriority.Action2,
	ShootHip = Enum.AnimationPriority.Action3,
	ShootAim = Enum.AnimationPriority.Action3,
	Draw = Enum.AnimationPriority.Action4,
	Reload = Enum.AnimationPriority.Action4,
	Unpin = Enum.AnimationPriority.Action4,
	Throw = Enum.AnimationPriority.Action4,
	Attack = Enum.AnimationPriority.Action4,
}

local LOOPED_BY_ROLE: { [string]: boolean } = {
	Hold = true,
	Aim = true,
	ShootHip = false,
	ShootAim = false,
	Draw = false,
	Reload = false,
	Unpin = false,
	Throw = false,
	Attack = false,
}

local function loadTrack(animator: Animator, role: string, animationId: string?): AnimationTrack?
	if not animationId or animationId == "" then
		return nil
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	warn(animation, animation.AnimationId)
	local track = animator:LoadAnimation(animation)
	animation:Destroy()

	track.Looped = LOOPED_BY_ROLE[role] or false
	track.Priority = PRIORITY_BY_ROLE[role] or Enum.AnimationPriority.Action

	return track
end

function AnimationSetLoader.Load(
	animator: Animator?,
	clips: { [string]: string }?,
	layer: "Viewmodel" | "Character"
): TrackSet
	local tracks: TrackSet = {}
	if not animator or not clips then
		return tracks
	end

	for role, animationId in clips do
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
