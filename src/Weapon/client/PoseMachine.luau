--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local FSMLib = require(ReplicatedStorage.shared.Libs.FSM)
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local AnimationSetLoader = require(StarterPlayer.StarterPlayerScripts.client.Weapon.AnimationSetLoader)

type Role = AnimationSetLoader.Role
type TrackSet = AnimationSetLoader.TrackSet

export type PoseState = "Drawing" | "Hold" | "Aim" | "Reloading" | "Attacking" | "Unpinning" | "Throwing"

const ANIMATION_FADE_TIME = 0.15

const STATE_TO_ROLE: { [PoseState]: Role } = {
	Drawing = "Draw",
	Hold = "Hold",
	Aim = "Aim",
	Reloading = "Reload",
	Attacking = "Attack",
	Unpinning = "Unpin",
	Throwing = "Throw",
}

const TRANSITIONS_BY_KIND: { [GetGun.PoseKind]: FSMLib.Transitions<PoseState> } = {
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

const AUTO_ADVANCE: { [PoseState]: { next: PoseState, fallback: number } } = {
	Drawing = { next = "Hold", fallback = 0.3 },
	Reloading = { next = "Hold", fallback = 0.6 },
	Attacking = { next = "Hold", fallback = 0.35 },
	Unpinning = { next = "Aim", fallback = 0.3 },
	Throwing = { next = "Hold", fallback = 0.4 },
}

export type PoseMachine = {
	FSM: FSMLib.FSM<PoseState>,
	_viewmodelTracks: TrackSet,
	_characterTracks: TrackSet,
	_connections: { RBXScriptConnection },
	_advanceGeneration: number,
	_destroyed: boolean,

	_playRole: (self: PoseMachine, role: Role) -> (),
	_stopRole: (self: PoseMachine, role: Role) -> (),
	_enterState: (self: PoseMachine, state: PoseState) -> (),
	_leaveState: (self: PoseMachine, state: PoseState) -> (),
	_scheduleAutoAdvance: (
		self: PoseMachine,
		fromState: PoseState,
		nextState: PoseState,
		fallbackSeconds: number
	) -> (),

	PlayDraw: (self: PoseMachine, targetSeconds: number?) -> (),
	SetAiming: (self: PoseMachine, aiming: boolean) -> (),
	PlayShoot: (self: PoseMachine) -> (),
	PlayReload: (self: PoseMachine) -> (),
	PlayAttack: (self: PoseMachine) -> (),
	BeginThrow: (self: PoseMachine) -> (),
	ReleaseThrow: (self: PoseMachine) -> (),
	GetState: (self: PoseMachine) -> PoseState,
	Destroy: (self: PoseMachine) -> (),
}

local PoseMachine = {}
PoseMachine.__index = PoseMachine

function PoseMachine._playRole(self: PoseMachine, role: Role)
	const vmTrack = self._viewmodelTracks[role]
	const charTrack = self._characterTracks[role]
	if vmTrack then
		vmTrack:Play(ANIMATION_FADE_TIME)
	end
	if charTrack then
		charTrack:Play(ANIMATION_FADE_TIME)
	end
end

function PoseMachine._stopRole(self: PoseMachine, role: Role)
	const vmTrack = self._viewmodelTracks[role]
	const charTrack = self._characterTracks[role]
	if vmTrack then
		vmTrack:Stop(ANIMATION_FADE_TIME)
	end
	if charTrack then
		charTrack:Stop(ANIMATION_FADE_TIME)
	end
end

function PoseMachine._enterState(self: PoseMachine, state: PoseState)
	self:_playRole(STATE_TO_ROLE[state])

	const advance = AUTO_ADVANCE[state]
	if advance then
		self:_scheduleAutoAdvance(state, advance.next, advance.fallback)
	end
end

function PoseMachine._leaveState(self: PoseMachine, state: PoseState)
	self:_stopRole(STATE_TO_ROLE[state])

	self._advanceGeneration += 1
end

function PoseMachine._scheduleAutoAdvance(
	self: PoseMachine,
	fromState: PoseState,
	nextState: PoseState,
	fallbackSeconds: number
)
	const generation = self._advanceGeneration
	const role = STATE_TO_ROLE[fromState]
	const track = self._viewmodelTracks[role] or self._characterTracks[role]

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
		const role = STATE_TO_ROLE["Drawing"]
		const vmTrack = self._viewmodelTracks[role]
		const charTrack = self._characterTracks[role]
		if vmTrack and vmTrack.Length > 0 then
			vmTrack:AdjustSpeed(vmTrack.Length / targetSeconds)
		end
		if charTrack and charTrack.Length > 0 then
			charTrack:AdjustSpeed(charTrack.Length / targetSeconds)
		end
	end

	if self.FSM:Is("Drawing") then
		self:_enterState("Drawing")
	else
		self.FSM:ForceState("Drawing")
	end
end

function PoseMachine.SetAiming(self: PoseMachine, aiming: boolean)
	self.FSM:Transition(if aiming then "Aim" else "Hold")
end

function PoseMachine.PlayShoot(self: PoseMachine)
	const role: Role = if self.FSM:Is("Aim") then "ShootAim" else "ShootHip"
	const vmTrack = self._viewmodelTracks[role]
	const charTrack = self._characterTracks[role]
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

function PoseMachine.new(viewmodelTracks: TrackSet, characterTracks: TrackSet, poseKind: GetGun.PoseKind): PoseMachine
	const transitions = TRANSITIONS_BY_KIND[poseKind] or TRANSITIONS_BY_KIND["Firearm"]

	const self: PoseMachine = setmetatable({
		_viewmodelTracks = viewmodelTracks,
		_characterTracks = characterTracks,

		FSM = FSMLib.new("Drawing" :: PoseState, transitions),
		_connections = {} :: { RBXScriptConnection },
		_advanceGeneration = 0,
		_destroyed = false,
	}, PoseMachine) :: any

	self.FSM:OnTransition(function(previousState: PoseState, nextState: PoseState)
		self:_leaveState(previousState)
		self:_enterState(nextState)
	end)

	return self
end

return PoseMachine
