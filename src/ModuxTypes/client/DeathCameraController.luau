--!strict

export type Public = {
	Spectating: boolean,
	Setup: (self: Public) -> (),
	GetSpectateCFrame: (self: Public, shooterRoot: BasePart) -> CFrame,
	StopSpectating: (self: Public) -> (),
	StartSpectating: (self: Public, shooter: Player) -> (),
}

return {}
