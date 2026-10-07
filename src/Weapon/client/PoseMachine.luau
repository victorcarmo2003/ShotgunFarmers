--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local FSMLib = require(ReplicatedStorage.shared.Libs.FSM)
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local AnimationSetLoader = require(StarterPlayer.StarterPlayerScripts.client.Weapon.AnimationSetLoader)

type Role = AnimationSetLoader.Role
type TrackSet = AnimationSetLoader.TrackSet

export type PoseState =
	"Drawing"
	| "Hold"
	| "Aim"
	| "Reloading"
	| "Attacking"
	| "Unpinning"
	| "PinIdle"
	| "AimingIn"
	| "AimingOut"
	| "Throwing"
	| "ThrowingShort"

const ANIMATION_FADE_TIME = 0.15
const BASE_ROLE: Role = "Hold"
const DRAW_FADE_TIME = 0.05
const SHOOT_AIM_RELEASE_FADE = 0.1
const RELEASE_FRACTION: { [Role]: number } = {
	Throw = 0.35,
	ThrowShort = 0.75,
}
const RELEASE_FALLBACK: { [Role]: number } = {
	Throw = 0.07,
	ThrowShort = 0.35,
}

const TRANSITION_FADE: { [string]: number } = {
	["Hold>Unpinning"] = 0.1,
	["Unpinning>PinIdle"] = 0.1,
	["PinIdle>AimingIn"] = 0.06,
	["AimingIn>Aim"] = 0.06,
	["Aim>AimingOut"] = 0.06,
	["AimingOut>PinIdle"] = 0.06,
	["AimingIn>AimingOut"] = 0.1,
	["AimingOut>AimingIn"] = 0.1,
	["Aim>Throwing"] = 0.04,
	["PinIdle>ThrowingShort"] = 0.06,
	["Throwing>Drawing"] = 0.12,
	["ThrowingShort>Drawing"] = 0.06,
	["Drawing>Hold"] = 0.2,
}

const STATE_TO_ROLE: { [PoseState]: Role } = {
	Drawing = "Draw",
	Hold = "Hold",
	Aim = "Aim",
	Reloading = "Reload",
	Attacking = "Attack",
	Unpinning = "Unpin",
	PinIdle = "PinIdle",
	AimingIn = "AimIn",
	AimingOut = "AimOut",
	Throwing = "Throw",
	ThrowingShort = "ThrowShort",
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
		Unpinning = { "PinIdle" },
		PinIdle = { "AimingIn", "ThrowingShort" },
		AimingIn = { "Aim", "AimingOut" },
		Aim = { "AimingOut", "Throwing" },
		AimingOut = { "PinIdle", "AimingIn" },
		Throwing = { "Drawing", "Hold" },
		ThrowingShort = { "Drawing", "Hold" },
	},
}

const AUTO_ADVANCE: { [PoseState]: { next: PoseState, fallback: number } } = {
	Drawing = { next = "Hold", fallback = 0.3 },
	Reloading = { next = "Hold", fallback = 0.6 },
	Attacking = { next = "Hold", fallback = 0.35 },
	Unpinning = { next = "PinIdle", fallback = 0.3 },
	AimingIn = { next = "Aim", fallback = 0.3 },
	AimingOut = { next = "PinIdle", fallback = 0.3 },
	Throwing = { next = "Drawing", fallback = 0.4 },
	ThrowingShort = { next = "Drawing", fallback = 0.5 },
}

export type PoseMachine = {
	FSM: FSMLib.FSM<PoseState>,
	_viewmodelTracks: TrackSet,
	_characterTracks: TrackSet,
	_connections: { RBXScriptConnection },
	_advanceGeneration: number,
	_destroyed: boolean,

	_playRole: (self: PoseMachine, role: Role, fade: number) -> (),
	_stopRole: (self: PoseMachine, role: Role, fade: number) -> (),
	_enterState: (self: PoseMachine, state: PoseState, fade: number) -> (),
	_leaveState: (self: PoseMachine, state: PoseState, fade: number) -> (),
	_scheduleAutoAdvance: (
		self: PoseMachine,
		fromState: PoseState,
		nextState: PoseState,
		fallbackSeconds: number
	) -> (),

	PlayDraw: (self: PoseMachine, targetSeconds: number?) -> (),
	SetAiming: (self: PoseMachine, aiming: boolean, cutShootAim: boolean?) -> (),
	IsShootAimPlaying: (self: PoseMachine) -> boolean,
	PlayShoot: (self: PoseMachine) -> (),
	PlayReload: (self: PoseMachine) -> (),
	PlayAttack: (self: PoseMachine) -> (),
	BeginThrow: (self: PoseMachine) -> (),
	SetThrowStance: (self: PoseMachine, long: boolean) -> (),
	ReleaseThrow: (self: PoseMachine, short: boolean) -> (),
	PlayDiscard: (self: PoseMachine) -> (),
	GetState: (self: PoseMachine) -> PoseState,
	ThrowReleaseDelay: (self: PoseMachine, short: boolean) -> number,
	Destroy: (self: PoseMachine) -> (),
}

local PoseMachine = {}
PoseMachine.__index = PoseMachine

local function fadeFor(previousState: PoseState, nextState: PoseState): number
	const fade = TRANSITION_FADE[previousState .. ">" .. nextState]
	if fade then
		return fade
	end
	return if nextState == "Drawing" then DRAW_FADE_TIME else ANIMATION_FADE_TIME
end

function PoseMachine._playRole(self: PoseMachine, role: Role, fade: number)
	for _, track in { self._viewmodelTracks[role], self._characterTracks[role] } do
		if role == BASE_ROLE and track.IsPlaying then
			continue
		end
		track:Play(fade)
	end
end

function PoseMachine._stopRole(self: PoseMachine, role: Role, fade: number)
	if role == BASE_ROLE then
		return
	end

	for _, track in { self._viewmodelTracks[role], self._characterTracks[role] } do
		track:Stop(fade)
	end
end

function PoseMachine._enterState(self: PoseMachine, state: PoseState, fade: number)
	self:_playRole(STATE_TO_ROLE[state], fade)

	const advance = AUTO_ADVANCE[state]
	if advance then
		self:_scheduleAutoAdvance(state, advance.next, advance.fallback)
	end
end

function PoseMachine._leaveState(self: PoseMachine, state: PoseState, fade: number)
	self:_stopRole(STATE_TO_ROLE[state], fade)

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

	if not track then
		task.delay(fallbackSeconds, advance)
		return
	end

	const speed = if track.Speed > 0 then track.Speed else 1
	if track.Length > 0 then
		const fade = fadeFor(fromState, nextState)
		task.delay(math.max(track.Length / speed - fade, 0), advance)
	end
	table.insert(self._connections, track.Stopped:Once(advance))
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
		self:_enterState("Drawing", DRAW_FADE_TIME)
	else
		self.FSM:ForceState("Drawing")
	end
end

function PoseMachine.SetAiming(self: PoseMachine, aiming: boolean, cutShootAim: boolean?)
	if not aiming and cutShootAim then
		for _, track in { self._viewmodelTracks.ShootAim, self._characterTracks.ShootAim } do
			if track and track.IsPlaying then
				track:Stop(SHOOT_AIM_RELEASE_FADE)
			end
		end
	end
	self.FSM:Transition(if aiming then "Aim" else "Hold")
end

function PoseMachine.IsShootAimPlaying(self: PoseMachine): boolean
	const track = self._viewmodelTracks.ShootAim
	return track ~= nil and track.IsPlaying
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

function PoseMachine.PlayDiscard(self: PoseMachine)
	self:_playRole("Discard", ANIMATION_FADE_TIME)
end

function PoseMachine.SetThrowStance(self: PoseMachine, long: boolean)
	self.FSM:Transition(if long then "AimingIn" else "AimingOut")
end

function PoseMachine.ReleaseThrow(self: PoseMachine, short: boolean)
	self.FSM:Transition(if short then "ThrowingShort" else "Throwing")
end

function PoseMachine.GetState(self: PoseMachine): PoseState
	return self.FSM:GetState()
end

function PoseMachine.ThrowReleaseDelay(self: PoseMachine, short: boolean): number
	const role: Role = if short then "ThrowShort" else "Throw"
	const track = self._viewmodelTracks[role] or self._characterTracks[role]
	if not track or track.Length <= 0 then
		return RELEASE_FALLBACK[role]
	end

	const speed = if track.Speed > 0 then track.Speed else 1
	return track.Length * RELEASE_FRACTION[role] / speed
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
		const fade = fadeFor(previousState, nextState)
		self:_leaveState(previousState, fade)
		self:_enterState(nextState, fade)
	end)

	self:_playRole(BASE_ROLE, 0)

	return self
end

return PoseMachine
