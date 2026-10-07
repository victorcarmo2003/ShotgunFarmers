--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterNet = require(ReplicatedStorage.shared.Character.Net)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Vide = require(ReplicatedStorage.Packages.Vide)

type MovementState = CharacterNet.MovementState
type MovementAction = CharacterNet.MovementAction
type MovementRecord = { State: MovementState, WalkSpeed: number }

export type Public = {
	CameraTween: Tween?,
	Character: Model?,
	FallSpeed: number,
	Humanoid: Humanoid?,
	HumanoidConnection: RBXScriptConnection?,
	IsMoving: Vide.Source<boolean>,
	IsSliding: boolean,
	Landed: SignalLib.Signal<number>,
	MovementState: Vide.Source<MovementState>,
	Player: Player,
	PreviousHumanoidState: Enum.HumanoidStateType?,
	SlideDirection: Vector3,
	SlideSpeed: number,
	WalkSpeed: number?,
	Setup: (self: Public) -> (),
	CancelCameraTween: (self: Public) -> (),
	ApplyCameraOffset: (self: Public, instant: boolean) -> (),
	SetHumanoid: (self: Public, humanoid: Humanoid) -> (),
	BindCharacter: (self: Public, character: Model?) -> (),
	GetCurrentPosition: (self: Public) -> Vector3?,
	GetMoveDirection: (self: Public) -> Vector3,
	Perform: (self: Public, action: MovementAction) -> boolean,
	ApplyWalkSpeed: (self: Public) -> (),
	Apply: (self: Public, record: MovementRecord) -> (),
	TryStartSlide: (self: Public) -> (),
	EndSlide: (self: Public) -> (),
	StopSlide: (self: Public) -> (),
	StepSlide: (self: Public, deltaTime: number) -> (),
	OnLanded: (self: Public, fallSpeed: number) -> (),
	StepFalling: (self: Public) -> (),
	StepMoving: (self: Public) -> (),
	BindKeys: (self: Public) -> (),
}

return {}
