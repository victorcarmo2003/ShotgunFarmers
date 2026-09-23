--!strict

export type Public = {
	Effect: ColorCorrectionEffect,
	Setup: (self: Public) -> (),
	SetSaturation: (self: Public, value: number) -> (),
}

return {}
