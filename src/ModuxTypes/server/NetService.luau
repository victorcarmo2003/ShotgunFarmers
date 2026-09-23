--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lync = require(ReplicatedStorage.Packages.Lync)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

export type Public = {
	Audience: Lync.Group,
	ClientReady: SignalLib.Signal<Player>,
	Ready: { [Player]: boolean },
	Running: boolean,
	Setup: (self: Public) -> (),
	IsReady: (self: Public, player: Player) -> boolean,
	IsRunning: (self: Public) -> boolean,
}

return {}
