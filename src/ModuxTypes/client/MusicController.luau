--!strict

export type Public = {
	BaseVolume: number,
	Context: string,
	CurrentSound: Sound?,
	EndedConnection: RBXScriptConnection?,
	FadeTween: Tween?,
	Multiplier: number,
	MusicFolder: Folder,
	Playlist: { Sound },
	PlaylistIndex: number,
	Setup: (self: Public) -> (),
	DesiredContext: (self: Public) -> string,
	SyncContext: (self: Public) -> (),
	CurrentMultiplier: (self: Public) -> number,
	ApplyVolume: (self: Public) -> (),
	PlayNext: (self: Public) -> (),
}

return {}
