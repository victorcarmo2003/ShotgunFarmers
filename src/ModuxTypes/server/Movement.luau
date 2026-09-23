--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterNet = require(ReplicatedStorage.shared.Character.Net)
local FSMLib = require(ReplicatedStorage.shared.Libs.FSM)

type State = CharacterNet.MovementState

export type Public = {
	Instance: Instance,
	Owner: Player,
	State: FSMLib.FSM<State>,
	WalkSpeed: number,
	Setup: (self: Public) -> (),
	Publish: (self: Public) -> (),
	Enter: (self: Public, state: State, walkSpeed: number) -> boolean,
	StartWalk: (self: Public) -> boolean,
	StartRun: (self: Public) -> boolean,
	StartCrouch: (self: Public) -> boolean,
	StartSlide: (self: Public) -> boolean,
	Perform: (self: Public, action: CharacterNet.MovementAction) -> boolean,
	Reset: (self: Public) -> (),
}

return {}
