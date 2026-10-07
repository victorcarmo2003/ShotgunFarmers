--!strict

type Sample = {
	point: Vector3,
	part: BasePart,
}
type Resolved = {
	cframe: CFrame,
	valid: boolean,
	hasGround: boolean,
}
type RecentSpawn = {
	pos: Vector3,
	time: number,
}

export type Public = {
	Destination: { [Player]: CFrame },
	Enabled: boolean,
	Epoch: { [Player]: number },
	OverlapParams: OverlapParams,
	Pending: { [Player]: boolean },
	Probe: Part,
	RayParams: RaycastParams,
	RecentSpawns: { RecentSpawn },
	SlotOf: { [Player]: number },
	SlotProvider: ((Player) -> number?)?,
	Slots: { [number]: Player },
	Spawning: { [Player]: boolean },
	Setup: (self: Public) -> (),
	GetSpawnParts: (self: Public) -> { BasePart },
	ApplyFilter: (self: Public) -> (),
	SampleCandidates: (self: Public, parts: { BasePart }) -> { Sample },
	Resolve: (self: Public, point: Vector3, part: BasePart) -> Resolved?,
	GetEnemyPositions: (self: Public, player: Player) -> { Vector3 },
	PruneRecent: (self: Public) -> (),
	PickSpawn: (self: Public, player: Player, parts: { BasePart }) -> CFrame?,
	RandomPointOn: (self: Public, part: BasePart) -> CFrame,
	GetTeamSpawnCFrame: (self: Public, teamName: string) -> CFrame?,
	ReleaseSlot: (self: Public, player: Player) -> (),
	AssignSlot: (self: Public, player: Player) -> number,
	GetSlotCFrame: (self: Public, slot: number) -> CFrame?,
	MoveToSlot: (self: Public, player: Player, slot: number) -> (),
	ArrangeSlots: (self: Public, assignments: { [Player]: number }) -> (),
	GetLobbyDestination: (self: Public, player: Player) -> CFrame?,
	GetMatchDestination: (self: Public, player: Player) -> CFrame?,
	GetDestination: (self: Public, player: Player) -> CFrame?,
	SpawnPlayer: (self: Public, player: Player) -> (),
	Respawn: (self: Public, player: Player, delay: number?) -> (),
	RespawnAll: (self: Public) -> (),
	Enable: (self: Public) -> (),
	Forget: (self: Public, player: Player) -> (),
}

return {}
