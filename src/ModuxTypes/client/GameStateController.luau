--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameState = require(ReplicatedStorage.shared.Match.GameState)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Public = {
	Changed: SignalLib.Signal<GameState.State, GameState.State>,
	State: Vide.Source<GameState.State>,
	Setup: (self: Public) -> (),
	Get: (self: Public) -> GameState.State,
	Is: (self: Public, state: GameState.State) -> boolean,
	IsLobby: (self: Public) -> boolean,
	IsLoading: (self: Public) -> boolean,
	IsInMatch: (self: Public) -> boolean,
	Can: (self: Public, capability: GameState.Capability) -> boolean,
	Capability: (self: Public, capability: GameState.Capability) -> () -> boolean,
	Watch: (self: Public, capability: GameState.Capability, callback: (boolean) -> ()) -> () -> (),
	Apply: (self: Public, value: any) -> (),
}

return {}
