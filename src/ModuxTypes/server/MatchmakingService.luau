--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchmakingNet = require(ReplicatedStorage.shared.Matchmaking.Net)

type PlayMode = MatchmakingNet.PlayMode
type State = MatchmakingNet.State
type Target = { Key: string, AccessCode: string }
type Finder = (userIds: { number }) -> (Target?, string?)
type Search = {
	Token: number,
	Squad: string,
	Leader: Player,
	UserIds: { number },
	Target: Target?,
	Started: number,
}

export type Public = {
	LastPlay: number,
	LobbyActive: boolean,
	MatchActive: boolean,
	Order: { Player },
	Returning: { [Player]: boolean },
	RoomCache: { MatchmakingNet.Room },
	RoomCacheAt: number,
	RoomListAt: { [Player]: number },
	Search: Search?,
	States: { [Player]: State },
	Token: number,
	Setup: (self: Public) -> (),
	SetStatus: (self: Public, players: { Player }, state: State, reason: string?) -> (),
	GetLeader: (self: Public) -> Player?,
	PublishLeader: (self: Public) -> (),
	IsBusy: (self: Public) -> boolean,
	EndSearch: (self: Public, token: number?, keepTraveling: boolean?) -> (),
	Validate: (self: Public, player: Player) -> string?,
	Create: (self: Public, modeName: string, private: boolean, userIds: { number }, chosenMap: string?, withCode: boolean?) -> (Target?, string?),
	FindTarget: (self: Public, mode: PlayMode, userIds: { number }) -> (Target?, string?),
	Travelers: (self: Public) -> { Player },
	FindRoom: (self: Public, code: string, userIds: { number }) -> (Target?, string?),
	Run: (self: Public, search: Search, find: Finder) -> (),
	Play: (self: Public, player: Player, mode: string) -> (boolean, string),
	CreateRoom: (self: Public, player: Player, mode: string, mapName: string, private: boolean) -> (boolean, string),
	JoinRoom: (self: Public, player: Player, code: string) -> (boolean, string),
	JoinMatch: (self: Public, player: Player, key: string) -> (boolean, string),
	ListRooms: (self: Public, player: Player) -> { MatchmakingNet.Room },
	Begin: (self: Public, player: Player, find: Finder) -> (boolean, string),
	OnTeleportFailed: (self: Public, player: Player, reason: string) -> (),
	Cancel: (self: Public, player: Player) -> (),
	ReturnToLobby: (self: Public, player: Player, reason: string?) -> (),
	ReturnAll: (self: Public, reason: string?) -> (),
	InSquads: (self: Public, player: Player) -> boolean,
	AdmissionProblem: (self: Public, player: Player) -> string?,
	Admit: (self: Public, player: Player) -> (),
	ActivateLobby: (self: Public) -> (),
	ActivateMatch: (self: Public) -> (),
	OnPlayerAdded: (self: Public, player: Player) -> (),
	OnPlayerRemoving: (self: Public, player: Player) -> (),
	BindNet: (self: Public) -> (),
	Start: (self: Public) -> (),
}

return {}
