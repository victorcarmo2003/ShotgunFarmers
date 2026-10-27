--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)
local RankSettings = require(ReplicatedStorage.shared.Rank.RankSettings)

type Category = RankSettings.Category
type Entry = RankSettings.Entry
export type Values = { [Category]: number }

export type Public = {
	Boards: { [Category]: { Entry } },
	Disposers: { [Player]: () -> () },
	Lobby: boolean,
	Names: { [number]: string },
	Saved: { [Player]: Values },
	Stored: { [Category]: { Entry } },
	Stores: { [Category]: OrderedDataStore },
	Values: { [Player]: Values },
	Warned: { [string]: boolean },
	Setup: (self: Public) -> (),
	WarnOnce: (self: Public, label: string, reason: any) -> (),
	GetStore: (self: Public, category: Category) -> OrderedDataStore,
	Read: (self: Public, player: Player) -> Values?,
	SendMine: (self: Public, player: Player) -> (),
	Watch: (self: Public, player: Player) -> (),
	Unwatch: (self: Public, player: Player) -> (),
	Save: (self: Public, player: Player) -> (),
	SaveAll: (self: Public) -> (),
	Fetch: (self: Public, category: Category) -> { Entry }?,
	Merge: (self: Public, category: Category) -> { Entry },
	ResolveNames: (self: Public, userIds: { number }) -> (),
	NameOf: (self: Public, userId: number) -> string,
	Rebuild: (self: Public) -> (),
	Refresh: (self: Public) -> (),
	Publish: (self: Public, to: Lync.Recipient) -> (),
	StartLobby: (self: Public) -> (),
	Forget: (self: Public, player: Player) -> (),
}

return {}
