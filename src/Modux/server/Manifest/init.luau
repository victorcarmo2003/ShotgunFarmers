--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local AdminService = require(ServerScriptService.server.ModuxTypes.AdminService)
local CharacterService = require(ServerScriptService.server.ModuxTypes.CharacterService)
local Movement = require(ServerScriptService.server.ModuxTypes.Movement)
local MovementService = require(ServerScriptService.server.ModuxTypes.MovementService)
local SpawnService = require(ServerScriptService.server.ModuxTypes.SpawnService)
local DayNightService = require(ServerScriptService.server.ModuxTypes.DayNightService)
local HitService = require(ServerScriptService.server.ModuxTypes.HitService)
local NetService = require(ServerScriptService.server.ModuxTypes.NetService)
local IDService = require(ServerScriptService.server.ModuxTypes.IDService)
local PlayerBillboardService = require(ServerScriptService.server.ModuxTypes.PlayerBillboardService)
local PlayerService = require(ServerScriptService.server.ModuxTypes.PlayerService)
local ProfileService = require(ServerScriptService.server.ModuxTypes.ProfileService)
local RoundService = require(ServerScriptService.server.ModuxTypes.RoundService)
local Seed = require(ServerScriptService.server.ModuxTypes.Seed)
local SnapshotService = require(ServerScriptService.server.ModuxTypes.SnapshotService)
local Vital = require(ServerScriptService.server.ModuxTypes.Vital)
local VitalService = require(ServerScriptService.server.ModuxTypes.VitalService)
local Equipment = require(ServerScriptService.server.ModuxTypes.Equipment)
local Gun = require(ServerScriptService.server.ModuxTypes.Gun)
local WeaponService = require(ServerScriptService.server.ModuxTypes.WeaponService)
local Zone = require(ServerScriptService.server.ModuxTypes.Zone)
local ZoneService = require(ServerScriptService.server.ModuxTypes.ZoneService)

export type AllServices = {
	AdminService: AdminService.Public,
	CharacterService: CharacterService.Public,
	MovementService: MovementService.Public,
	SpawnService: SpawnService.Public,
	DayNightService: DayNightService.Public,
	HitService: HitService.Public,
	NetService: NetService.Public,
	IDService: IDService.Public,
	PlayerBillboardService: PlayerBillboardService.Public,
	PlayerService: PlayerService.Public,
	ProfileService: ProfileService.Public,
	RoundService: RoundService.Public,
	SnapshotService: SnapshotService.Public,
	VitalService: VitalService.Public,
	WeaponService: WeaponService.Public,
	ZoneService: ZoneService.Public,
}

export type AllComponents = {
	Movement: Movement.Public,
	Seed: Seed.Public,
	Vital: Vital.Public,
	Equipment: Equipment.Public,
	Gun: Gun.Public,
	Zone: Zone.Public,
}

export type ComponentAccess = {
	Movement: {
		Get: (self: any, instance: Instance) -> Movement.Public?,
		Create: (self: any, instance: Instance) -> Movement.Public,
		All: (self: any) -> { Movement.Public },
		Destroy: (self: any, instance: Instance) -> (),
	},
	Seed: {
		Get: (self: any, instance: Instance) -> Seed.Public?,
		Create: (self: any, instance: Instance) -> Seed.Public,
		All: (self: any) -> { Seed.Public },
		Destroy: (self: any, instance: Instance) -> (),
	},
	Vital: {
		Get: (self: any, instance: Instance) -> Vital.Public?,
		Create: (self: any, instance: Instance) -> Vital.Public,
		All: (self: any) -> { Vital.Public },
		Destroy: (self: any, instance: Instance) -> (),
	},
	Equipment: {
		Get: (self: any, instance: Instance) -> Equipment.Public?,
		Create: (self: any, instance: Instance) -> Equipment.Public,
		All: (self: any) -> { Equipment.Public },
		Destroy: (self: any, instance: Instance) -> (),
	},
	Gun: {
		Get: (self: any, instance: Instance) -> Gun.Public?,
		Create: (self: any, instance: Instance) -> Gun.Public,
		All: (self: any) -> { Gun.Public },
		Destroy: (self: any, instance: Instance) -> (),
	},
	Zone: {
		Get: (self: any, instance: Instance) -> Zone.Public?,
		Create: (self: any, instance: Instance) -> Zone.Public,
		All: (self: any) -> { Zone.Public },
		Destroy: (self: any, instance: Instance) -> (),
	},
}

return {}
