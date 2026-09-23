--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

export type Public = {
	CharacterAdded: SignalLib.Signal<Player, Model>,
	CharacterRemoving: SignalLib.Signal<Player, Model>,
	Connections: { [Player]: { RBXScriptConnection } },
	PlayerAdded: SignalLib.Signal<Player>,
	PlayerRemoving: SignalLib.Signal<Player>,
	Setup: (self: Public) -> (),
	Watch: (self: Public, player: Player) -> (),
	Forget: (self: Public, player: Player) -> (),
}

return {}
