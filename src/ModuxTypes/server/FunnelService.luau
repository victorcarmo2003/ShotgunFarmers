--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Funnels = require(ReplicatedStorage.shared.Analytics.Funnels)

type FunnelName = Funnels.FunnelName
export type Session = {
	Id: string,
	Step: number,
}
export type TeleportPayload = {
	Sessions: { [string]: { [string]: Session } },
	Marks: { [string]: { [string]: number } },
}

export type Public = {
	LastClient: { [Player]: { [string]: number } },
	Marks: { [Player]: { [string]: number } },
	Sessions: { [Player]: { [FunnelName]: Session } },
	Validators: { [FunnelName]: (player: Player, step: string, detail: string) -> boolean },
	Verbose: boolean,
	Setup: (self: Public) -> (),
	Validate: (self: Public, funnel: FunnelName, validator: (player: Player, step: string, detail: string) -> boolean) -> (),
	FromClient: (self: Public, player: Player, funnel: FunnelName, step: string, detail: string) -> (),
	Fields: (self: Public, fields: { string }?) -> { [string]: any }?,
	Log: (self: Public, label: string, send: () -> ()) -> (),
	Get: (self: Public, player: Player, funnel: FunnelName) -> Session?,
	Begin: (self: Public, player: Player, funnel: FunnelName) -> string,
	Resume: (self: Public, player: Player, funnel: FunnelName, id: string, step: number) -> string,
	Current: (self: Public, player: Player, funnel: FunnelName) -> Session?,
	Mark: (self: Public, player: Player, key: string) -> (),
	TakeMark: (self: Public, player: Player, key: string) -> number?,
	Export: (self: Public, players: { Player }, funnels: { FunnelName }) -> TeleportPayload,
	Import: (self: Public, player: Player, payload: any) -> (),
	End: (self: Public, player: Player, funnel: FunnelName) -> (),
	Step: (self: Public, player: Player, funnel: FunnelName, stepName: string, fields: { string }?) -> boolean,
	Drop: (self: Public, player: Player, funnel: FunnelName, reason: string, fields: { string }?) -> boolean,
	Event: (self: Public, player: Player, name: string, value: number?, fields: { string }?) -> (),
}

return {}
