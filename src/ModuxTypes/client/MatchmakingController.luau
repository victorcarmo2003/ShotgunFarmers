--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchmakingNet = require(ReplicatedStorage.shared.Matchmaking.Net)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Vide = require(ReplicatedStorage.Packages.Vide)

type PlayMode = MatchmakingNet.PlayMode
type State = MatchmakingNet.State

export type Public = {
	Failed: SignalLib.Signal<string>,
	Reason: Vide.Source<string>,
	State: Vide.Source<State>,
	Setup: (self: Public) -> (),
	IsBusy: (self: Public) -> boolean,
	Play: (self: Public, mode: PlayMode) -> (boolean, string),
	Cancel: (self: Public) -> (),
	ReturnToLobby: (self: Public) -> (),
}

return {}
