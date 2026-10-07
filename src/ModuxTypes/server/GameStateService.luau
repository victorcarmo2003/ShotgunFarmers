--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local GameState = require(ReplicatedStorage.shared.Match.GameState)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

export type Public = {
	Changed: SignalLib.Signal<GameState.State, GameState.State>,
	Override: Charm.Atom<GameState.State?>,
	Resolved: Charm.Atom<boolean>,
	State: (() -> GameState.State)?,
	Setup: (self: Public) -> (),
	Get: (self: Public) -> GameState.State,
	Is: (self: Public, state: GameState.State) -> boolean,
	IsInMatch: (self: Public) -> boolean,
	Can: (self: Public, capability: GameState.Capability) -> boolean,
	OnChanged: (self: Public, callback: (GameState.State, GameState.State) -> ()) -> SignalLib.Connection,
	Force: (self: Public, state: GameState.State?) -> (),
}

return {}
