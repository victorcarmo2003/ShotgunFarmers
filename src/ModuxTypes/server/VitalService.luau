--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

export type Public = {
	Dead: { [Player]: boolean },
	Died: SignalLib.Signal<Player>,
	LastReset: { [Player]: number },
	Restored: SignalLib.Signal<Player>,
	Watched: { [Humanoid]: boolean },
	Setup: (self: Public) -> (),
	Reset: (self: Public, player: Player) -> (),
	Watch: (self: Public, player: Player, character: Model) -> (),
	Kill: (self: Public, player: Player) -> (),
}

return {}
