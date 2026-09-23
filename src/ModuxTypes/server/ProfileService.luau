--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Atomic = require(ReplicatedStorage.shared.Types.Atomic)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Struct = require(ReplicatedStorage.shared.Types.Struct)
local Template = require(ServerScriptService.server.Profile.ProfileService.Template)

export type Data = typeof(Template)
export type Profile = Atomic.Table<Data>

export type Public = {
	Disposers: { [Player]: () -> () },
	Loaded: SignalLib.Signal<Player, Profile>,
	Profiles: { [Player]: Profile },
	Sessions: { [Player]: any },
	Store: any,
	Setup: (self: Public) -> (),
	Get: (self: Public, player: Player) -> Profile?,
	Update: (self: Public, player: Player, patch: Struct.Partial<Data>) -> (),
	Replicate: (self: Public, player: Player) -> (),
	Bind: (self: Public, player: Player, session: any) -> Profile,
	Load: (self: Public, player: Player) -> (),
	Forget: (self: Public, player: Player) -> (),
	Unload: (self: Public, player: Player) -> (),
}

return {}
