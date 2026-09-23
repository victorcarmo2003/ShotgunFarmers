--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuickZone = require(ReplicatedStorage.Packages.QuickZone)

export type Public = {
	Instance: Instance,
	Area: QuickZone.Zone?,
	Disconnect: (() -> ())?,
	Observer: QuickZone.Observer<Player>?,
	Part: BasePart?,
	Setup: (self: Public) -> (),
	Observe: (self: Public) -> (),
}

return {}
