--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local GetAnimations = require(ReplicatedStorage.shared.Character.GetAnimations)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type CoreAnimState = "Idle" | "Walk" | "Run" | "CrouchIdle" | "CrouchWalk" | "Jump" | "Fall" | "Land"

const FADE_TIME = 0.15

const IDLE_GRACE = 0.2

const LAND_HOLD = 0.2

const TICK_RATE = 30

const LOOPED_STATES: { [CoreAnimState]: boolean } = {
	Idle = true,
	Walk = true,
	Run = true,
	CrouchIdle = true,
	CrouchWalk = true,
	Jump = false,
	Fall = true,
	Land = false,
}

const PRIORITY_BY_STATE: { [CoreAnimState]: Enum.AnimationPriority } = {
	Idle = Enum.AnimationPriority.Idle,
	Walk = Enum.AnimationPriority.Movement,
	Run = Enum.AnimationPriority.Movement,
	CrouchIdle = Enum.AnimationPriority.Movement,
	CrouchWalk = Enum.AnimationPriority.Movement,
	Jump = Enum.AnimationPriority.Movement,
	Fall = Enum.AnimationPriority.Movement,
	Land = Enum.AnimationPriority.Movement,
}

local function coreIds(): { [CoreAnimState]: string }

	const core = GetAnimations.Core()
	return {
		Idle = core.Idle,
		Walk = core.Walk,
		Run = core.Run,
		CrouchIdle = core.CrouchIdle,
		CrouchWalk = core.CrouchWalk,
		Jump = core.Jump,
		Fall = core.Fall,
		Land = core.Land,
	}
end

local function loadTrack(animator: Animator, id: string): AnimationTrack?
	if id == "" then
		return nil
	end

	const animation = Instance.new("Animation")
	animation.AnimationId = id
	const track = animator:LoadAnimation(animation)
	animation:Destroy()
	return track
end

const AnimateController = Modux.Controller("AnimateController", {
	Require = { "MovementController" },
	Priority = 700,
})

function AnimateController:Setup()
	self.Tracks = nil :: { [CoreAnimState]: AnimationTrack? }?
	self.CurrentState = nil :: CoreAnimState?
	self.TrackedHumanoid = nil :: Humanoid?
	self.HumanoidStateConnection = nil :: RBXScriptConnection?
	self.Airborne = false :: boolean
	self.LandHoldUntil = 0 :: number
	self.LastMovingClock = 0 :: number
end

function AnimateController:ClearTracks()
	const tracks = self.Tracks
	if tracks then
		for _, track in tracks do
			if track then
				track:Stop(0)
				track:Destroy()
			end
		end
	end

	self.Tracks = nil
	self.CurrentState = nil
end

function AnimateController:LoadTracks(animator: Animator)
	const ids = coreIds()
	const tracks: { [CoreAnimState]: AnimationTrack? } = {}
	for state, looped in LOOPED_STATES do
		const track = loadTrack(animator, ids[state])
		if track then
			track.Looped = looped
			track.Priority = PRIORITY_BY_STATE[state]
		end
		tracks[state] = track
	end

	self.Tracks = tracks
	self.CurrentState = nil
	self.Airborne = false
	self.LandHoldUntil = 0
	self.LastMovingClock = 0
	self:SetState(self:ComputeBaseState())
end

function AnimateController:Attach(humanoid: Humanoid?)
	if self.HumanoidStateConnection then
		self.HumanoidStateConnection:Disconnect()
		self.HumanoidStateConnection = nil
	end

	self:ClearTracks()
	self.TrackedHumanoid = nil

	if not humanoid then
		return
	end

	const animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	self.TrackedHumanoid = humanoid
	self:LoadTracks(animator)
	self.HumanoidStateConnection = humanoid.StateChanged:Connect(function(_old, new)
		self:OnHumanoidStateChanged(new)
	end)
end

function AnimateController:SetState(state: CoreAnimState)
	if state == self.CurrentState then
		return
	end

	const tracks = self.Tracks
	if not tracks then
		return
	end

	const currentState = self.CurrentState
	const previousTrack = if currentState then tracks[currentState] else nil
	if previousTrack then
		previousTrack:Stop(FADE_TIME)
	end

	const nextTrack = tracks[state]
	if nextTrack then
		nextTrack:Play(FADE_TIME)
	end

	self.CurrentState = state
end

function AnimateController:StopAll()
	const tracks = self.Tracks
	const currentState = self.CurrentState
	if tracks and currentState then
		const track = tracks[currentState]
		if track then
			track:Stop(FADE_TIME)
		end
	end

	self.CurrentState = nil
end

function AnimateController:ComputeBaseState(): CoreAnimState
	const humanoid = self.TrackedHumanoid
	const moveDirection = if humanoid then humanoid.MoveDirection else Vector3.zero
	const isMovingNow = moveDirection.Magnitude > 0

	const now = os.clock()
	if isMovingNow then
		self.LastMovingClock = now
	end
	const isMoving = isMovingNow or (now - self.LastMovingClock) < IDLE_GRACE

	const mode = self.Dependencies.MovementController.MovementState()
	if mode == "Crouch" or mode == "Sliding" then
		return if isMoving then "CrouchWalk" else "CrouchIdle"
	elseif mode == "Running" then
		return if isMoving then "Run" else "Idle"
	end

	return if isMoving then "Walk" else "Idle"
end

function AnimateController:OnHumanoidStateChanged(state: Enum.HumanoidStateType)
	if state == Enum.HumanoidStateType.Jumping then
		self.Airborne = true
		self:SetState("Jump")
	elseif state == Enum.HumanoidStateType.Freefall then
		self.Airborne = true
		self:SetState("Fall")
	elseif state == Enum.HumanoidStateType.Landed then
		self.Airborne = false
		self.LandHoldUntil = os.clock() + LAND_HOLD
		self:SetState("Land")
	else
		self.Airborne = false
	end
end

AnimateController:OnTick(function(self)
	const humanoid = self.Dependencies.MovementController.Humanoid
	if humanoid ~= self.TrackedHumanoid then
		self:Attach(humanoid)
	end

	if not self.TrackedHumanoid then
		return
	end

	if self.Dependencies.MovementController.MovementState() == "Dead" then
		self:StopAll()
		return
	end

	if self.LandHoldUntil > 0 and os.clock() < self.LandHoldUntil then
		return
	end
	self.LandHoldUntil = 0

	if self.Airborne then
		return
	end

	self:SetState(self:ComputeBaseState())
end, TICK_RATE)

AnimateController:OnInit(function(self)
	self:Setup()
end)

return AnimateController
