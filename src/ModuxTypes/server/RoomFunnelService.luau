--!strict

export type Public = {
	Active: boolean,
	Started: boolean,
	Setup: (self: Public) -> (),
	StepAll: (self: Public, step: string, fields: { string }?) -> (),
	OnJoined: (self: Public) -> (),
	OnMatchStarted: (self: Public) -> (),
	Activate: (self: Public) -> (),
}

return {}
