--!strict

export type Source = "Leaderstats" | "Options" | "RobloxMenu" | "Practice"

export type Public = {
	Blur: BlurEffect,
	Count: number,
	Sources: { [string]: boolean },
	Tween: Tween?,
	Setup: (self: Public) -> (),
	IsOpen: (self: Public) -> boolean,
	FovDelta: (self: Public) -> number,
	ApplyBlur: (self: Public) -> (),
	Set: (self: Public, source: Source, on: boolean) -> (),
	Open: (self: Public, source: Source) -> (),
	Close: (self: Public, source: Source) -> (),
}

return {}
