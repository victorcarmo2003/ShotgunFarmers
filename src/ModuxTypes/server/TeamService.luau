--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local BotTypes = require(ServerScriptService.server.Bot.BotTypes)

type Fighter = BotTypes.Fighter

export type Public = {
	Changed: SignalLib.Signal<Fighter, string?>,
	Teams: { [Fighter]: string },
	Setup: (self: Public) -> (),
	IsTeamMode: (self: Public) -> boolean,
	Count: (self: Public, teamName: string) -> number,
	PickTeam: (self: Public) -> string,
	Assign: (self: Public, fighter: Fighter) -> (),
	Release: (self: Public, fighter: Fighter) -> (),
	GetTeam: (self: Public, fighter: Fighter) -> string?,
	SameTeam: (self: Public, first: Fighter, second: Fighter) -> boolean,
}

return {}
