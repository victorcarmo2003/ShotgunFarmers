--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

export type Public = {
	Changed: SignalLib.Signal<Player, string?>,
	Teams: { [Player]: string },
	Setup: (self: Public) -> (),
	IsTeamMode: (self: Public) -> boolean,
	Count: (self: Public, teamName: string) -> number,
	PickTeam: (self: Public) -> string,
	Assign: (self: Public, player: Player) -> (),
	Release: (self: Public, player: Player) -> (),
	GetTeam: (self: Public, player: Player) -> string?,
	SameTeam: (self: Public, first: Player, second: Player) -> boolean,
}

return {}
