--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SquadRecord = require(ReplicatedStorage.shared.Party.SquadRecord)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

type Record = SquadRecord.Record

export type Public = {
	Admitted: { [number]: boolean },
	Changed: SignalLib.Signal<>,
	Checked: { [number]: boolean },
	Departing: { [number]: boolean },
	Key: string,
	LobbyActive: boolean,
	Local: boolean,
	MatchActive: boolean,
	Misses: { [number]: number },
	Notify: SignalLib.Signal<Player, string>,
	Record: Record?,
	Relocating: { [Player]: boolean },
	Removals: { [number]: boolean },
	ReturnKeys: { [Player]: string },
	SyncQueued: boolean,
	Syncing: boolean,
	Traveling: { [number]: number },
	Setup: (self: Public) -> (),
	GetKey: (self: Public) -> string,
	GetRecord: (self: Public) -> Record?,
	IsLobbyActive: (self: Public) -> boolean,
	IsLocal: (self: Public) -> boolean,
	IsMember: (self: Public, userId: number) -> boolean,
	HasRoom: (self: Public) -> boolean,
	GetLeader: (self: Public) -> Player?,
	PresentMembers: (self: Public) -> { Player },
	PlayBlocker: (self: Public) -> string?,
	MarkTraveling: (self: Public, players: { Player }, traveling: boolean) -> (),
	AnyTraveling: (self: Public) -> boolean,
	SetDeparting: (self: Public, player: Player, departing: boolean) -> (),
	CurrentKey: (self: Public, player: Player) -> string?,
	SetReturnKey: (self: Public, player: Player, key: string) -> (),
	GetReturnKey: (self: Public, player: Player) -> string?,
	Remove: (self: Public, key: string, userId: number) -> (),
	CheckAbsent: (self: Public) -> { [number]: boolean },
	Sync: (self: Public) -> (),
	RequestSync: (self: Public) -> (),
	Publish: (self: Public, target: Player?) -> (),
	Arrange: (self: Public) -> (),
	Relocate: (self: Public, player: Player, message: string) -> (),
	Renew: (self: Public) -> (),
	ActivateLobby: (self: Public) -> (),
	ActivateMatch: (self: Public) -> (),
}

return {}
