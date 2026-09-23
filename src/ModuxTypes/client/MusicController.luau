--!strict

export type Public = {
	CurrentSound: Sound?,
	EndedConnection: RBXScriptConnection?,
	MusicFolder: Folder,
	Playlist: { Sound },
	PlaylistIndex: number,
	Setup: (self: Public) -> (),
	PlayNext: (self: Public) -> (),
}

return {}
