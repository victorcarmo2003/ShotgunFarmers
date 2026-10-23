--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local BotTypes = require(ServerScriptService.server.Bot.BotTypes)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

type Bot = BotTypes.Bot

export type Public = {
	Added: SignalLib.Signal<Bot>,
	Bots: { [number]: Bot },
	Died: SignalLib.Signal<Bot>,
	Removing: SignalLib.Signal<Bot>,
	Serial: number,
	Setup: (self: Public) -> (),
	Create: (self: Public, displayName: string, avatarId: number) -> Bot,
	Remove: (self: Public, bot: Bot) -> (),
	FromID: (self: Public, id: number) -> Bot?,
	All: (self: Public) -> { Bot },
	Count: (self: Public) -> number,
	Revive: (self: Public, bot: Bot, position: Vector3, lookAt: Vector3) -> (),
	Damage: (self: Public, bot: Bot, amount: number) -> (number, boolean),
	Heal: (self: Public, bot: Bot, amount: number) -> (),
	TraceBot: (self: Public, bot: Bot, origin: Vector3, direction: Vector3, position: Vector3?) -> (number?, number),
	RayHit: (self: Public, origin: Vector3, direction: Vector3, maxDistance: number, ignore: Bot?) -> (Bot?, number, number),
}

return {}
