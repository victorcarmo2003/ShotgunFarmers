--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

export type Role = "Lobby" | "Match"
export type Presence = { Job: string, Role: Role, Squad: string, At: number }
export type Message = { [string]: any }

export type Public = {
	Active: boolean,
	JobId: string,
	Map: MemoryStoreHashMap?,
	Message: SignalLib.Signal<Message>,
	Remote: boolean,
	Role: Role,
	Squads: { [Player]: string },
	Subscribed: boolean,
	Warned: { [string]: boolean },
	Setup: (self: Public) -> (),
	WarnOnce: (self: Public, label: string, reason: any) -> (),
	GetMap: (self: Public) -> MemoryStoreHashMap,
	IsActive: (self: Public) -> boolean,
	Topic: (self: Public, jobId: string) -> string,
	GetSquad: (self: Public, player: Player) -> string?,
	SetSquad: (self: Public, player: Player, key: string?) -> (),
	Write: (self: Public, player: Player) -> (),
	Clear: (self: Public, userId: number) -> (),
	Read: (self: Public, userId: number) -> (Presence?, boolean),
	Send: (self: Public, jobId: string, message: Message) -> (boolean, string?),
	SendToUser: (self: Public, userId: number, message: Message) -> (boolean, string?),
	Subscribe: (self: Public) -> (),
	BeatAll: (self: Public) -> (),
	Activate: (self: Public, role: Role) -> (),
}

return {}
