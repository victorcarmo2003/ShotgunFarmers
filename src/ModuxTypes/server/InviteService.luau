--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PartyNet = require(ReplicatedStorage.shared.Party.Net)

type Incoming = {
	Id: string,
	From: number,
	FromName: string,
	Squad: string,
	Reply: string,
	Expires: number,
}
type Outgoing = {
	From: Player,
	To: number,
	Expires: number,
}
type Result = "Accepted" | "Declined" | "Expired" | "Unavailable" | "Failed"
type FriendCache = { Ids: { [number]: boolean }, Names: { [number]: string }, At: number }
type PresenceEntry = { Value: any, At: number }

export type Public = {
	Budget: { [Player]: { Start: number, Count: number } },
	Friends: { [number]: FriendCache },
	Incoming: { [Player]: { Incoming } },
	Joining: { [Player]: string },
	LastEntries: { [Player]: { PartyNet.Friend } },
	LastFriends: { [Player]: number },
	LastInvite: { [Player]: number },
	Outgoing: { [string]: Outgoing },
	PresenceCache: { [number]: PresenceEntry },
	Setup: (self: Public) -> (),
	Notice: (self: Public, player: Player, message: string) -> (),
	Spend: (self: Public, player: Player) -> boolean,
	ReadPresence: (self: Public, player: Player, userId: number) -> (any, boolean),
	PrunePresenceCache: (self: Public) -> (),
	LoadFriends: (self: Public, player: Player) -> FriendCache?,
	IsFriend: (self: Public, player: Player, userId: number) -> boolean,
	NameOf: (self: Public, owner: Player, userId: number) -> string,
	ListFriends: (self: Public, player: Player, candidates: { number }) -> { PartyNet.Friend },
	Validate: (self: Public, player: Player, userId: number) -> string?,
	Invite: (self: Public, player: Player, userId: number) -> (boolean, string),
	Reply: (self: Public, invite: Incoming, from: Player, result: Result, reason: string?) -> (),
	Take: (self: Public, player: Player, id: string) -> Incoming?,
	Deliver: (self: Public, message: { [string]: any }) -> (),
	HandleReply: (self: Public, message: { [string]: any }) -> (),
	UndoJoin: (self: Public, player: Player) -> (),
	JoinLobby: (self: Public, player: Player, key: string) -> (boolean, string?),
	Join: (self: Public, player: Player, key: string) -> (boolean, string?),
	Respond: (self: Public, player: Player, id: string, accept: boolean) -> (),
	OnMessage: (self: Public, message: { [string]: any }) -> (),
}

return {}
