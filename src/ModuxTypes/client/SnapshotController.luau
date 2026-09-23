--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterNet = require(ReplicatedStorage.shared.Character.Net)

type MovementState = CharacterNet.MovementState

export type Public = {
	GetCurrentState: (self: Public) -> MovementState,
	SendSnapshot: (self: Public) -> (),
}

return {}
