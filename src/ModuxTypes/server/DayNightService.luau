--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

export type Cycle = "Day" | "Night" | "Idle" | "Transition"

export type Public = {
	Cycle: Cycle,
	CycleChanged: SignalLib.Signal<Cycle, Cycle>,
	Day: number,
	Running: boolean,
	SecondsLeft: number,
	Setup: (self: Public) -> (),
	SetCycle: (self: Public, cycle: Cycle) -> (),
	Transition: (self: Public, target: "Day" | "Night") -> (),
	Toggle: (self: Public) -> (),
	StartCycle: (self: Public) -> (),
	GetCycle: (self: Public) -> Cycle,
	GetDay: (self: Public) -> number,
}

return {}
