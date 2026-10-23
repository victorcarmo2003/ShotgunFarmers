--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local AdminService = require(ServerScriptService.server.ModuxTypes.AdminService)
local FunnelService = require(ServerScriptService.server.ModuxTypes.FunnelService)
local PartyFunnelService = require(ServerScriptService.server.ModuxTypes.PartyFunnelService)
local PlantLoopService = require(ServerScriptService.server.ModuxTypes.PlantLoopService)
local ReviveFunnelService = require(ServerScriptService.server.ModuxTypes.ReviveFunnelService)
local RoomFunnelService = require(ServerScriptService.server.ModuxTypes.RoomFunnelService)
local RoundsFunnelService = require(ServerScriptService.server.ModuxTypes.RoundsFunnelService)
local ShopFunnelService = require(ServerScriptService.server.ModuxTypes.ShopFunnelService)
local SkinFunnelService = require(ServerScriptService.server.ModuxTypes.SkinFunnelService)
local BotRegistryService = require(ServerScriptService.server.ModuxTypes.BotRegistryService)
local BotService = require(ServerScriptService.server.ModuxTypes.BotService)
local CareerService = require(ServerScriptService.server.ModuxTypes.CareerService)
local CharacterService = require(ServerScriptService.server.ModuxTypes.CharacterService)
local Movement = require(ServerScriptService.server.ModuxTypes.Movement)
local MovementService = require(ServerScriptService.server.ModuxTypes.MovementService)
local SpawnService = require(ServerScriptService.server.ModuxTypes.SpawnService)
local DayNightService = require(ServerScriptService.server.ModuxTypes.DayNightService)
local GoldenAppleService = require(ServerScriptService.server.ModuxTypes.GoldenAppleService)
local HitService = require(ServerScriptService.server.ModuxTypes.HitService)
local LavaService = require(ServerScriptService.server.ModuxTypes.LavaService)
local OnlineService = require(ServerScriptService.server.ModuxTypes.OnlineService)
local EnvironmentService = require(ServerScriptService.server.ModuxTypes.EnvironmentService)
local GameStateService = require(ServerScriptService.server.ModuxTypes.GameStateService)
local ServerRoleService = require(ServerScriptService.server.ModuxTypes.RoleService)
local MatchRegistryService = require(ServerScriptService.server.ModuxTypes.MatchRegistryService)
local MatchmakingService = require(ServerScriptService.server.ModuxTypes.MatchmakingService)
local RouterService = require(ServerScriptService.server.ModuxTypes.RouterService)
local TeleportGateway = require(ServerScriptService.server.ModuxTypes.TeleportGateway)
local NetService = require(ServerScriptService.server.ModuxTypes.NetService)
local OptionsService = require(ServerScriptService.server.ModuxTypes.OptionsService)
local InviteService = require(ServerScriptService.server.ModuxTypes.InviteService)
local PresenceService = require(ServerScriptService.server.ModuxTypes.PresenceService)
local SquadService = require(ServerScriptService.server.ModuxTypes.SquadService)
local SquadStore = require(ServerScriptService.server.ModuxTypes.SquadStore)
local IDService = require(ServerScriptService.server.ModuxTypes.IDService)
local PlayerBillboardService = require(ServerScriptService.server.ModuxTypes.PlayerBillboardService)
local PlayerService = require(ServerScriptService.server.ModuxTypes.PlayerService)
local PracticeService = require(ServerScriptService.server.ModuxTypes.PracticeService)
local ProfileService = require(ServerScriptService.server.ModuxTypes.ProfileService)
local MapVoteService = require(ServerScriptService.server.ModuxTypes.MapVoteService)
local RoundFreezeService = require(ServerScriptService.server.ModuxTypes.RoundFreezeService)
local RoundService = require(ServerScriptService.server.ModuxTypes.RoundService)
local RestockService = require(ServerScriptService.server.ModuxTypes.RestockService)
local Seed = require(ServerScriptService.server.ModuxTypes.Seed)
local ShopService = require(ServerScriptService.server.ModuxTypes.ShopService)
local SnapshotService = require(ServerScriptService.server.ModuxTypes.SnapshotService)
local MatchStatsService = require(ServerScriptService.server.ModuxTypes.MatchStatsService)
local TeamService = require(ServerScriptService.server.ModuxTypes.TeamService)
local Vital = require(ServerScriptService.server.ModuxTypes.Vital)
local VitalService = require(ServerScriptService.server.ModuxTypes.VitalService)
local Equipment = require(ServerScriptService.server.ModuxTypes.Equipment)
local Gun = require(ServerScriptService.server.ModuxTypes.Gun)
local ThrowableService = require(ServerScriptService.server.ModuxTypes.ThrowableService)
local WeaponService = require(ServerScriptService.server.ModuxTypes.WeaponService)
local WeaponSpawnService = require(ServerScriptService.server.ModuxTypes.WeaponSpawnService)
local Zone = require(ServerScriptService.server.ModuxTypes.Zone)
local ZoneService = require(ServerScriptService.server.ModuxTypes.ZoneService)

export type AllServices = {
	AdminService: AdminService.Public,
	FunnelService: FunnelService.Public,
	PartyFunnelService: PartyFunnelService.Public,
	PlantLoopService: PlantLoopService.Public,
	ReviveFunnelService: ReviveFunnelService.Public,
	RoomFunnelService: RoomFunnelService.Public,
	RoundsFunnelService: RoundsFunnelService.Public,
	ShopFunnelService: ShopFunnelService.Public,
	SkinFunnelService: SkinFunnelService.Public,
	BotRegistryService: BotRegistryService.Public,
	BotService: BotService.Public,
	CareerService: CareerService.Public,
	CharacterService: CharacterService.Public,
	MovementService: MovementService.Public,
	SpawnService: SpawnService.Public,
	DayNightService: DayNightService.Public,
	GoldenAppleService: GoldenAppleService.Public,
	HitService: HitService.Public,
	LavaService: LavaService.Public,
	OnlineService: OnlineService.Public,
	EnvironmentService: EnvironmentService.Public,
	GameStateService: GameStateService.Public,
	ServerRoleService: ServerRoleService.Public,
	MatchRegistryService: MatchRegistryService.Public,
	MatchmakingService: MatchmakingService.Public,
	RouterService: RouterService.Public,
	TeleportGateway: TeleportGateway.Public,
	NetService: NetService.Public,
	OptionsService: OptionsService.Public,
	InviteService: InviteService.Public,
	PresenceService: PresenceService.Public,
	SquadService: SquadService.Public,
	SquadStore: SquadStore.Public,
	IDService: IDService.Public,
	PlayerBillboardService: PlayerBillboardService.Public,
	PlayerService: PlayerService.Public,
	PracticeService: PracticeService.Public,
	ProfileService: ProfileService.Public,
	MapVoteService: MapVoteService.Public,
	RoundFreezeService: RoundFreezeService.Public,
	RoundService: RoundService.Public,
	RestockService: RestockService.Public,
	ShopService: ShopService.Public,
	SnapshotService: SnapshotService.Public,
	MatchStatsService: MatchStatsService.Public,
	TeamService: TeamService.Public,
	VitalService: VitalService.Public,
	ThrowableService: ThrowableService.Public,
	WeaponService: WeaponService.Public,
	WeaponSpawnService: WeaponSpawnService.Public,
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
