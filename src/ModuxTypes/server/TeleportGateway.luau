--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

export type TeleportData = { [string]: any }
export type Reservation = { AccessCode: string, ServerId: string }

export type Public = {
	Failed: SignalLib.Signal<Player, string>,
	InFlight: { [Player]: boolean },
	Retries: { [Player]: number },
	Simulated: boolean,
	Setup: (self: Public) -> (),
	IsSimulated: (self: Public) -> boolean,
	IsTeleporting: (self: Public, player: Player) -> boolean,
	Reserve: (self: Public) -> (Reservation?, string?),
	Teleport: (self: Public, players: { Player }, accessCode: string?, data: TeleportData?) -> (boolean, string?),
	HandleInitFailed: (self: Public, player: Player, message: string, options: Instance?) -> (),
}

return {}
