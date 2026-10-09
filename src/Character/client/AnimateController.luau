--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local GetAnimations = require(ReplicatedStorage.shared.Character.GetAnimations)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type CoreAnimState =
	"Idle"
	| "Walk"
	| "WalkBackward"
	| "Run"
	| "RunBackward"
	| "CrouchIdle"
	| "CrouchWalk"
	| "CrouchWalkForward"
	| "CrouchWalkBackward"
	| "Jump"
	| "Fall"
	| "Land"

const FADE_TIME = 0.15

const IDLE_GRACE = 0.2

const LAND_HOLD = 0.2

const TICK_RATE = 30

const DIRECTION_THRESHOLD = 0.35

const LOOPED_STATES: { [CoreAnimState]: boolean } = {
	Idle = true,
	Walk = true,
	WalkBackward = true,
	Run = true,
	RunBackward = true,
	CrouchIdle = true,
	CrouchWalk = true,
	CrouchWalkForward = true,
	CrouchWalkBackward = true,
	Jump = false,
	Fall = true,
	Land = false,
}

const PRIORITY_BY_STATE: { [CoreAnimState]: Enum.AnimationPriority } = {
	Idle = Enum.AnimationPriority.Idle,
	Walk = Enum.AnimationPriority.Movement,
	WalkBackward = Enum.AnimationPriority.Movement,
	Run = Enum.AnimationPriority.Movement,
	RunBackward = Enum.AnimationPriority.Movement,
	CrouchIdle = Enum.AnimationPriority.Movement,
	CrouchWalk = Enum.AnimationPriority.Movement,
	CrouchWalkForward = Enum.AnimationPriority.Movement,
	CrouchWalkBackward = Enum.AnimationPriority.Movement,
	Jump = Enum.AnimationPriority.Movement,
	Fall = Enum.AnimationPriority.Movement,
	Land = Enum.AnimationPriority.Movement,
}

local function pick(override: string?, fallback: string): string
	return if override and override ~= "" then override else fallback
end

local function animationIds(gunName: string?): { [CoreAnimState]: string }
	const core = GetAnimations.Core()
	const movement: GetAnimations.MovementSet = (if gunName then GetAnimations.Movement(gunName) else nil) or {}
	return {
		Idle = pick(movement.Idle, core.Idle),
		Walk = pick(movement.Walk, core.Walk),
		WalkBackward = pick(movement.WalkBackward, ""),
		Run = pick(movement.RunForward, core.Run),
		RunBackward = pick(movement.RunBackward, ""),
		CrouchIdle = pick(movement.CrouchIdle, core.CrouchIdle),
		CrouchWalk = pick(movement.CrouchWalk, core.CrouchWalk),
		CrouchWalkForward = pick(movement.CrouchWalkForward, ""),
		CrouchWalkBackward = pick(movement.CrouchWalkBackward, ""),
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
	Require = { "MovementController", "WeaponController" },
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
	self.GunName = nil :: string?
end

function AnimateController:EquippedGun(): string?
	const gunData = self.Dependencies.WeaponController:GunData()
	return if gunData then gunData.DisplayName else nil
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
	self.GunName = self:EquippedGun()
	const ids = animationIds(self.GunName)
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

	local forward = 0
	const root = if humanoid then humanoid.RootPart else nil
	if root and isMovingNow then
		forward = moveDirection.Unit:Dot(root.CFrame.LookVector)
	end
	const backward = forward < -DIRECTION_THRESHOLD
	const ahead = forward > DIRECTION_THRESHOLD

	const mode = self.Dependencies.MovementController.MovementState()
	if mode == "Crouch" or mode == "Sliding" then
		if not isMoving then
			return "CrouchIdle"
		end
		return self:Prefer(if backward then "CrouchWalkBackward" elseif ahead then "CrouchWalkForward" else "CrouchWalk", "CrouchWalk")
	elseif mode == "Running" then
		if not isMoving then
			return "Idle"
		end
		return self:Prefer(if backward then "RunBackward" else "Run", "Run")
	end

	if not isMoving then
		return "Idle"
	end
	return self:Prefer(if backward then "WalkBackward" else "Walk", "Walk")
end

function AnimateController:Prefer(state: CoreAnimState, fallback: CoreAnimState): CoreAnimState
	const tracks = self.Tracks
	return if tracks and tracks[state] then state else fallback
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

	const tracked = self.TrackedHumanoid
	if not tracked then
		return
	end

	if self:EquippedGun() ~= self.GunName then
		const animator = tracked:FindFirstChildOfClass("Animator")
		if animator then
			self:ClearTracks()
			self:LoadTracks(animator)
		end
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
