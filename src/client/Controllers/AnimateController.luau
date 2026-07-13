local Modux = require(game.ReplicatedStorage.Shared.Modux)
local AnimateController = Modux.Controller("AnimateController")

const CROUCH_WALKSPEED_THRESHOLD = 15 -- abaixo disso conta como agachado (Crouch = 10, Walk/Run = 28 no MovementComponent)
const FADE_TIME = 0.15

const AnimationIds = {
	Idle = 108351629079504,
	Walk = 108083033842451,
	CrouchIdle = 123183890160107,
	CrouchWalk = 112432304826929,
}

local function LoadTrack(animator: Animator, id: number): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. id

	local track = animator:LoadAnimation(animation)
	track.Looped = true

	animation:Destroy()
	return track
end

AnimateController.GetState = function(self): string
	local humanoid = self.LocalHumanoid
	if not humanoid then
		return "Idle"
	end

	local isCrouching = humanoid.WalkSpeed <= CROUCH_WALKSPEED_THRESHOLD
	local isMoving = humanoid.MoveDirection.Magnitude > 0

	if isCrouching then
		return if isMoving then "CrouchWalk" else "CrouchIdle"
	end

	return if isMoving then "Walk" else "Idle"
end

AnimateController.LoadAnimator = function(self, humanoid: Humanoid)
	if self.Tracks then
		for _, track in self.Tracks do
			track:Stop(0)
			track:Destroy()
		end
	end

	local animator = humanoid:WaitForChild("Animator") :: Animator
	local tracks = {}
	for state, id in AnimationIds do
		tracks[state] = LoadTrack(animator, id)
	end

	self.Tracks = tracks
	self._currentState = nil
	self:SetState(self:GetState())
end

AnimateController.SetState = function(self, state: string)
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

AnimateController:OnTick(function(self)
	local humanoid = self.LocalHumanoid
	if humanoid ~= self._trackedHumanoid then
		self._trackedHumanoid = humanoid
		if humanoid then
			self:LoadAnimator(humanoid)
		end
	end

	if humanoid then
		self:SetState(self:GetState())
	end
end, Modux.TickRate.Hz30)

AnimateController:OnInit(function(self) end)

AnimateController:OnStart(function(self) end)

return AnimateController
