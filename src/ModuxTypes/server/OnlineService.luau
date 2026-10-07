--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)

export type Public = {
	Aggregator: boolean,
	Key: string,
	Map: MemoryStoreSortedMap?,
	Meta: MemoryStoreHashMap?,
	Remote: boolean,
	Total: number,
	Warned: { [string]: boolean },
	Setup: (self: Public) -> (),
	WarnOnce: (self: Public, label: string, reason: any) -> (),
	GetMap: (self: Public) -> MemoryStoreSortedMap,
	GetMeta: (self: Public) -> MemoryStoreHashMap,
	Heartbeat: (self: Public) -> (),
	Remove: (self: Public) -> (),
	Claim: (self: Public) -> boolean,
	Release: (self: Public) -> (),
	Sum: (self: Public) -> number?,
	Aggregate: (self: Public) -> (),
	ReadTotal: (self: Public) -> number?,
	Publish: (self: Public, to: Lync.Recipient) -> (),
	SetTotal: (self: Public, total: number) -> (),
	Refresh: (self: Public) -> (),
	StartLobby: (self: Public) -> (),
}

return {}
