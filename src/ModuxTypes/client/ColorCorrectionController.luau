--!strict

export type Public = {
	BaseSaturation: number,
	Effect: ColorCorrectionEffect,
	Gray: number,
	Setup: (self: Public) -> (),
	Apply: (self: Public) -> (),
	SetSaturation: (self: Public, value: number) -> (),
	SetGray: (self: Public, amount: number) -> (),
}

return {}
