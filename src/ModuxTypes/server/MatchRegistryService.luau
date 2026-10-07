--!strict

export type Entry = {
	AccessCode: string,
	Map: string,
	Mode: string,
	Players: number,
	Reserved: number,
	MaxPlayers: number,
	JoinInProgress: boolean,
	Private: boolean,
	UpdatedAt: number,
	Pending: { [string]: number },
}
export type Lobby = { Key: string, AccessCode: string, Players: number, Owner: number? }
export type Target = { Key: string, AccessCode: string }

export type Public = {
	Beating: boolean,
	ConfigMap: MemoryStoreHashMap?,
	Key: string,
	LastConfigRefresh: number,
	Queued: boolean,
	Registry: MemoryStoreSortedMap?,
	Running: boolean,
	WarnedReasons: { [string]: boolean },
	Setup: (self: Public) -> (),
	WarnOnce: (self: Public, label: string, reason: any) -> (),
	GetConfigMap: (self: Public) -> MemoryStoreHashMap,
	GetRegistry: (self: Public) -> MemoryStoreSortedMap,
	IsSimulated: (self: Public) -> boolean,
	Attempt: (self: Public, callback: () -> any, attempts: number?, backoff: number?, maxBackoff: number?) -> (boolean, any),
	FetchConfig: (self: Public, key: string, boot: boolean?) -> any?,
	SetConfig: (self: Public, key: string, config: { [string]: any }, ttl: number) -> (boolean, string?),
	UpdateConfig: (self: Public, key: string, transform: (any) -> any, ttl: number) -> boolean,
	FindLobby: (self: Public, key: string) -> Lobby?,
	CreateLobby: (self: Public, ownerId: number) -> (Target?, string?),
	GetLobbyKey: (self: Public) -> string?,
	GetOwner: (self: Public) -> number?,
	ListMatches: (self: Public) -> { [string]: Entry },
	HasRoom: (self: Public, entry: Entry, size: number, now: number) -> boolean,
	ReserveSlots: (self: Public, key: string, userIds: { number }) -> boolean,
	ReleaseSlots: (self: Public, key: string, userIds: { number }) -> (),
	AppendSquad: (self: Public, key: string, userIds: { number }) -> (),
	FindMatch: (self: Public, modes: { string }, userIds: { number }) -> Target?,
	RegisterMatch: (self: Public, key: string, config: { [string]: any }, userIds: { number }) -> boolean,
	IsPublicMatch: (self: Public) -> boolean,
	JoinInProgress: (self: Public) -> boolean,
	BeatMatch: (self: Public) -> (),
	RefreshConfigs: (self: Public) -> (),
	BeatLobby: (self: Public) -> (),
	Heartbeat: (self: Public) -> (),
	RequestHeartbeat: (self: Public) -> (),
	Cleanup: (self: Public) -> (),
	Begin: (self: Public) -> (),
}

return {}
