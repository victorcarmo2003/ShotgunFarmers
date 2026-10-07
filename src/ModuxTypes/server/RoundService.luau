--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Lync = require(ReplicatedStorage.Packages.Lync)
local RoundNet = require(ReplicatedStorage.shared.Round.Net)

export type Status = RoundNet.Status

export type Public = {
	Active: boolean,
	Held: number,
	Holding: boolean,
	Seconds: Charm.Atom<number>,
	Skips: { [string]: () -> boolean },
	Status: Charm.Atom<Status>,
	Setup: (self: Public) -> (),
	SetSkip: (self: Public, status: Status, shouldSkip: () -> boolean) -> (),
	ShouldHold: (self: Public) -> boolean,
	Enter: (self: Public, status: Status) -> (),
	Advance: (self: Public) -> (),
	Publish: (self: Public, to: Lync.Recipient) -> (),
}

return {}
