--!strict

export type Public = {
	StripDefaultAnimate: (self: Public, character: Model) -> (),
	DisableAccessoryQuery: (self: Public, character: Model) -> (),
	Sanitize: (self: Public, character: Model) -> (),
}

return {}
