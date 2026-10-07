--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)

export type Public = {
	Counts: { number },
	Granted: { [Player]: boolean },
	Open: boolean,
	Options: { string },
	Pool: { GetGun.GunNames },
	Votes: { [Player]: number },
	Wanted: { [Player]: GetGun.GunNames },
	Setup: (self: Public) -> (),
	ModeName: (self: Public) -> string?,
	ShouldVote: (self: Public) -> boolean,
	BuildPool: (self: Public) -> (),
	StartingEnabled: (self: Public) -> boolean,
	Roll: (self: Public) -> GetGun.GunNames?,
	Deal: (self: Public, player: Player) -> (),
	TakeStart: (self: Public, player: Player) -> GetGun.GunNames?,
	DealAll: (self: Public) -> (),
	ClearSeeds: (self: Public) -> (),
	Tally: (self: Public) -> (),
	OpenVote: (self: Public) -> (),
	Cast: (self: Public, player: Player, option: number) -> (),
	Pick: (self: Public) -> number,
	Conclude: (self: Public) -> string?,
	Apply: (self: Public, mapName: string) -> (),
	BeginRound: (self: Public) -> (),
	Forget: (self: Public, player: Player) -> (),
}

return {}
