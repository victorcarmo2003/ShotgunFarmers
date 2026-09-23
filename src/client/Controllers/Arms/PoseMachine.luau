--modux ignore file
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FSM = require(ReplicatedStorage.Shared.Utils.FSM)
local AnimationSetLoader = require(script.Parent.AnimationSetLoader)

type TrackSet = AnimationSetLoader.TrackSet

export type PoseState = "Drawing" | "Hold" | "Aim" | "Reloading" | "Attacking" | "Unpinning" | "Throwing"

local ANIMATION_FADE_TIME = 0.15

local STATE_TO_ROLE: { [PoseState]: string } = {
	Drawing = "Draw",
	Hold = "Hold",
	Aim = "Aim",
	Reloading = "Reload",
	Attacking = "Attack",
	Unpinning = "Unpin",
	Throwing = "Throw",
}

local TRANSITIONS_BY_KIND: { [string]: FSM.Transitions<PoseState> } = {
	Firearm = {
		Drawing = { "Hold" },
		Hold = { "Aim", "Reloading" },
		Aim = { "Hold", "Reloading" },
		Reloading = { "Hold" },
	},
	Melee = {
		Drawing = { "Hold" },
		Hold = { "Attacking" },
		Attacking = { "Hold" },
	},
	Throwable = {
		Drawing = { "Hold" },
		Hold = { "Unpinning" },
		Unpinning = { "Aim" },
		Aim = { "Throwing" },
		Throwing = { "Hold" },
	},
}

local AUTO_ADVANCE: { [PoseState]: { next: PoseState, fallback: number } } = {
	Drawing = { next = "Hold", fallback = 0.3 },
	Reloading = { next = "Hold", fallback = 0.6 },
	Attacking = { next = "Hold", fallback = 0.35 },
	Unpinning = { next = "Aim", fallback = 0.3 },
	Throwing = { next = "Hold", fallback = 0.4 },
}

export type PoseMachine = {
	FSM: FSM.FSM<PoseState>,
	_viewmodelTracks: TrackSet,
	_characterTracks: TrackSet,
	_connections: { RBXScriptConnection },
	_advanceGeneration: number,
	_destroyed: boolean,

	_playRole: (self: PoseMachine, role: string) -> (),
	_stopRole: (self: PoseMachine, role: string) -> (),
	_enterState: (self: PoseMachine, state: PoseState) -> (),
	_leaveState: (self: PoseMachine, state: PoseState) -> (),
	_scheduleAutoAdvance: (
		self: PoseMachine,
		fromState: PoseState,
		nextState: PoseState,
		fallbackSeconds: number
	) -> (),

	SetAiming: (self: PoseMachine, aiming: boolean) -> (),
	PlayShoot: (self: PoseMachine) -> (),
	PlayReload: (self: PoseMachine) -> (),
	PlayDraw: (self: PoseMachine, targetSeconds: number?) -> (),
	PlayAttack: (self: PoseMachine) -> (),
	BeginThrow: (self: PoseMachine) -> (),
	ReleaseThrow: (self: PoseMachine) -> (),
	GetState: (self: PoseMachine) -> PoseState,
	Destroy: (self: PoseMachine) -> (),
}

local PoseMachine = {}
PoseMachine.__index = PoseMachine

function PoseMachine._playRole(self: PoseMachine, role: string)
	local vmTrack = self._viewmodelTracks[role]
	local charTrack = self._characterTracks[role]
	if vmTrack then
		vmTrack:Play(ANIMATION_FADE_TIME)
	end
	if charTrack then
		charTrack:Play(ANIMATION_FADE_TIME)
	end
end

function PoseMachine._stopRole(self: PoseMachine, role: string)
	local vmTrack = self._viewmodelTracks[role]
	local charTrack = self._characterTracks[role]
	if vmTrack then
		vmTrack:Stop(ANIMATION_FADE_TIME)
	end
	if charTrack then
		charTrack:Stop(ANIMATION_FADE_TIME)
	end
end

function PoseMachine._enterState(self: PoseMachine, state: PoseState)
	local role = STATE_TO_ROLE[state]
	if role then
		self:_playRole(role)
	end

	local advance = AUTO_ADVANCE[state]
	if advance then
		self:_scheduleAutoAdvance(state, advance.next, advance.fallback)
	end
end

function PoseMachine._leaveState(self: PoseMachine, state: PoseState)
	local role = STATE_TO_ROLE[state]
	if role then
		self:_stopRole(role)
	end

	self._advanceGeneration += 1
end

function PoseMachine._scheduleAutoAdvance(
	self: PoseMachine,
	fromState: PoseState,
	nextState: PoseState,
	fallbackSeconds: number
)
	local generation = self._advanceGeneration
	local role = STATE_TO_ROLE[fromState]
	local track = role and (self._viewmodelTracks[role] or self._characterTracks[role])

	local function advance()
		if self._destroyed or self._advanceGeneration ~= generation then
			return
		end
		self.FSM:Transition(nextState)
	end

	if track then
		table.insert(self._connections, track.Stopped:Once(advance))
	else
		task.delay(fallbackSeconds, advance)
	end
end

function PoseMachine.PlayDraw(self: PoseMachine, targetSeconds: number?)
	if targetSeconds and targetSeconds > 0 then
		local role = STATE_TO_ROLE.Drawing
		local vmTrack = self._viewmodelTracks[role]
		local charTrack = self._characterTracks[role]
		if vmTrack and vmTrack.Length > 0 then
			vmTrack:AdjustSpeed(vmTrack.Length / targetSeconds)
		end
		if charTrack and charTrack.Length > 0 then
			charTrack:AdjustSpeed(charTrack.Length / targetSeconds)
		end
	end

	self:_enterState("Drawing")
end

function PoseMachine.SetAiming(self: PoseMachine, aiming: boolean)
	self.FSM:Transition(if aiming then "Aim" else "Hold")
end

function PoseMachine.PlayShoot(self: PoseMachine)
	local role = if self.FSM:Is("Aim") then "ShootAim" else "ShootHip"
	local vmTrack = self._viewmodelTracks[role]
	local charTrack = self._characterTracks[role]
	if vmTrack then
		vmTrack:Stop(0)
		vmTrack:Play(0)
	end
	if charTrack then
		charTrack:Stop(0)
		charTrack:Play(0)
	end
end

function PoseMachine.PlayReload(self: PoseMachine)
	self.FSM:Transition("Reloading")
end

function PoseMachine.PlayAttack(self: PoseMachine)
	self.FSM:Transition("Attacking")
end

function PoseMachine.BeginThrow(self: PoseMachine)
	self.FSM:Transition("Unpinning")
end

function PoseMachine.ReleaseThrow(self: PoseMachine)
	self.FSM:Transition("Throwing")
end

function PoseMachine.GetState(self: PoseMachine): PoseState
	return self.FSM:GetState()
end

function PoseMachine.Destroy(self: PoseMachine)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._advanceGeneration += 1

	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)

	self.FSM:Destroy()
end

function PoseMachine.new(viewmodelTracks: TrackSet, characterTracks: TrackSet, poseKind: string): PoseMachine
	local transitions = TRANSITIONS_BY_KIND[poseKind] or TRANSITIONS_BY_KIND.Firearm

	local self = setmetatable({
		_viewmodelTracks = viewmodelTracks,
		_characterTracks = characterTracks,

		FSM = FSM.new("Drawing" :: PoseState, transitions),
		_connections = {} :: { RBXScriptConnection },
		_advanceGeneration = 0,
		_destroyed = false,
	}, PoseMachine) :: PoseMachine

	self.FSM:OnTransition(function(previousState: PoseState, nextState: PoseState)
		self:_leaveState(previousState)
		self:_enterState(nextState)
	end)

	return self
end

return PoseMachine
