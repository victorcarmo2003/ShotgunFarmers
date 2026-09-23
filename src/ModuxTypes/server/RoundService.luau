--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Lync = require(ReplicatedStorage.Packages.Lync)
local RoundNet = require(ReplicatedStorage.shared.Round.Net)

export type Status = RoundNet.Status

export type Public = {
	Seconds: Charm.Atom<number>,
	Status: Charm.Atom<Status>,
	Setup: (self: Public) -> (),
	Enter: (self: Public, status: Status) -> (),
	Advance: (self: Public) -> (),
	Publish: (self: Public, to: Lync.Recipient) -> (),
}

return {}
