local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local Modux = require(ReplicatedStorage.Shared.Modux)
local GetAnimations = require(ReplicatedStorage.Shared.Utils.GetAnimations)

local AnimateController = Modux.Controller("AnimateController"):Import("MovementController")
type Self = typeof(AnimateController)

export type CoreAnimState = "Idle" | "Walk" | "Run" | "CrouchIdle" | "CrouchWalk" | "Jump" | "Fall" | "Land"

local FADE_TIME = 0.15

local IDLE_GRACE = 0.2

local LAND_HOLD = 0.2

local LOOPED_STATES: { [CoreAnimState]: boolean } = {
	Idle = true,
	Walk = true,
	Run = true,
	CrouchIdle = true,
	CrouchWalk = true,
	Jump = false,
	Fall = true,
	Land = false,
}

local PRIORITY_BY_STATE: { [CoreAnimState]: Enum.AnimationPriority } = {
	Idle = Enum.AnimationPriority.Idle,
	Walk = Enum.AnimationPriority.Movement,
	Run = Enum.AnimationPriority.Movement,
	CrouchIdle = Enum.AnimationPriority.Movement,
	CrouchWalk = Enum.AnimationPriority.Movement,
	Jump = Enum.AnimationPriority.Movement,
	Fall = Enum.AnimationPriority.Movement,
	Land = Enum.AnimationPriority.Movement,
}

local function loadTrack(animator: Animator, id: string): AnimationTrack?
	if id == "" then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local track = animator:LoadAnimation(animation)
	animation:Destroy()
	return track
end

AnimateController.LoadAnimator = function(self: Self, humanoid: Humanoid)
	if self.Tracks then
		for _, track in self.Tracks do
			if track then
				track:Stop(0)
				track:Destroy()
			end
		end
	end

	local animator = humanoid:WaitForChild("Animator") :: Animator
	local core = GetAnimations:Core()
	local tracks: { [CoreAnimState]: AnimationTrack? } = {}
	for state in LOOPED_STATES do
		local track = loadTrack(animator, core[state])
		if track then
			track.Looped = LOOPED_STATES[state]
			track.Priority = PRIORITY_BY_STATE[state]
		end
		tracks[state] = track
	end

	self.Tracks = tracks
	self._currentState = nil :: CoreAnimState?
	self._airborne = false
	self._landHoldUntil = 0
	self._lastMovingClock = 0
	self:SetState(self:ComputeBaseState())
end

AnimateController.SetState = function(self: Self, state: CoreAnimState)
	if state == self._currentState then
		return
	end

	local tracks = self.Tracks
	if not tracks then
		return
	end

	local previousTrack = self._currentState and tracks[self._currentState]
	if previousTrack then
		previousTrack:Stop(FADE_TIME)
	end

	local nextTrack = tracks[state]
	if nextTrack then
		nextTrack:Play(FADE_TIME)
	end

	self._currentState = state
end

AnimateController.StopAll = function(self: Self)
	local tracks = self.Tracks
	if tracks and self._currentState then
		local track = tracks[self._currentState]
		if track then
			track:Stop(FADE_TIME)
		end
	end
	self._currentState = nil
end

AnimateController.ComputeBaseState = function(self: Self): CoreAnimState
	local humanoid = self.LocalHumanoid
	local moveDirection = humanoid and humanoid.MoveDirection or Vector3.zero
	local isMovingNow = moveDirection.Magnitude > 0

	local now = os.clock()
	if isMovingNow then
		self._lastMovingClock = now
	end
	local isMoving = isMovingNow or (now - (self._lastMovingClock or 0)) < IDLE_GRACE

	local mode = Fusion.peek(self.MovementController.MovementState)
	if mode == "Crouch" then
		return if isMoving then "CrouchWalk" else "CrouchIdle"
	elseif mode == "Running" then
		return if isMoving then "Run" else "Idle"
	elseif mode == "Sliding" then
		return if isMoving then "CrouchWalk" else "CrouchIdle"
	end

	return if isMoving then "Walk" else "Idle"
end

AnimateController.OnHumanoidStateChanged = function(
	self: Self,
	_old: Enum.HumanoidStateType,
	new: Enum.HumanoidStateType
)
	if new == Enum.HumanoidStateType.Jumping then
		self._airborne = true
		self:SetState("Jump")
	elseif new == Enum.HumanoidStateType.Freefall then
		self._airborne = true
		self:SetState("Fall")
	elseif new == Enum.HumanoidStateType.Landed then
		self._airborne = false
		self._landHoldUntil = os.clock() + LAND_HOLD
		self:SetState("Land")
	else
		self._airborne = false
	end
end

AnimateController:OnTick(function(self)
	local humanoid = self.LocalHumanoid
	if humanoid ~= self._trackedHumanoid then
		if self._humanoidStateConnection then
			self._humanoidStateConnection:Disconnect()
			self._humanoidStateConnection = nil
		end

		self._trackedHumanoid = humanoid
		if humanoid then
			self:LoadAnimator(humanoid)
			self._humanoidStateConnection = humanoid.StateChanged:Connect(function(old, new)
				self:OnHumanoidStateChanged(old, new)
			end)
		end
	end

	if not humanoid then
		return
	end

	local mode = Fusion.peek(self.MovementController.MovementState)
	if mode == "Dead" then
		self:StopAll()
		return
	end

	if self._landHoldUntil > 0 and os.clock() < self._landHoldUntil then
		return
	end
	self._landHoldUntil = 0

	if self._airborne then
		return
	end

	self:SetState(self:ComputeBaseState())
end, Modux.TickRate.Hz30)

AnimateController:OnInit(function(self) end)

AnimateController:OnStart(function(self) end)

return AnimateController
