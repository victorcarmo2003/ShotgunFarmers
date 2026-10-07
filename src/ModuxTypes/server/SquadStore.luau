--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SquadRecord = require(ReplicatedStorage.shared.Party.SquadRecord)

type Record = SquadRecord.Record
type Status = SquadRecord.Status
export type JoinResult = "Ok" | "Missing" | "Full" | "Error"

export type Public = {
	Map: MemoryStoreHashMap?,
	Setup: (self: Public) -> (),
	GetMap: (self: Public) -> MemoryStoreHashMap,
	Get: (self: Public, key: string) -> (boolean, Record?),
	GrantToken: (self: Public, key: string, userId: number) -> (),
	HasToken: (self: Public, key: string, userId: number) -> boolean,
	Update: (self: Public, key: string, transform: (Record?) -> Record?) -> (boolean, Record?),
	Notify: (self: Public, record: Record?, key: string) -> (),
	AddMember: (self: Public, key: string, player: Player, status: Status) -> (JoinResult, Record?),
	RemoveMember: (self: Public, key: string, userId: number) -> (),
	Touch: (self: Public, key: string) -> (),
}

return {}
