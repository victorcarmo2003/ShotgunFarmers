--!strict

export type Public = {
	BaseVolume: number,
	CurrentSound: Sound?,
	EndedConnection: RBXScriptConnection?,
	FadeTween: Tween?,
	Multiplier: number,
	MusicFolder: Folder,
	Playlist: { Sound },
	PlaylistIndex: number,
	Setup: (self: Public) -> (),
	CurrentMultiplier: (self: Public) -> number,
	ApplyVolume: (self: Public) -> (),
	PlayNext: (self: Public) -> (),
}

return {}
