--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchmakingNet = require(ReplicatedStorage.shared.Matchmaking.Net)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Vide = require(ReplicatedStorage.Packages.Vide)

type PlayMode = MatchmakingNet.PlayMode
type State = MatchmakingNet.State
type Room = MatchmakingNet.Room
type RoomMode = MatchmakingNet.RoomMode

export type Public = {
	Failed: SignalLib.Signal<string>,
	Reason: Vide.Source<string>,
	RoomCode: Vide.Source<string>,
	Rooms: Vide.Source<{ Room }>,
	RoomsLoading: Vide.Source<boolean>,
	State: Vide.Source<State>,
	Setup: (self: Public) -> (),
	SyncRoomCode: (self: Public) -> (),
	MountRoomCode: (self: Public) -> (),
	IsBusy: (self: Public) -> boolean,
	Play: (self: Public, mode: PlayMode) -> (boolean, string),
	CreateRoom: (self: Public, mode: RoomMode, mapName: string, private: boolean) -> (boolean, string),
	JoinRoom: (self: Public, code: string) -> (boolean, string),
	JoinMatch: (self: Public, key: string) -> (boolean, string),
	RefreshRooms: (self: Public) -> (),
	Cancel: (self: Public) -> (),
	ReturnToLobby: (self: Public) -> (),
}

return {}
