--!strict

local ServerScriptService = game:GetService("ServerScriptService")

return {
	ServerScriptService.server.Admin.AdminService,
	ServerScriptService.server.Character.CharacterService,
	ServerScriptService.server.Character.Movement,
	ServerScriptService.server.Character.MovementService,
	ServerScriptService.server.Character.SpawnService,
	ServerScriptService.server.DayNight.DayNightService,
	ServerScriptService.server.Hit.HitService,
	ServerScriptService.server.Net.NetService,
	ServerScriptService.server.Player.IDService,
	ServerScriptService.server.Player.PlayerBillboardService,
	ServerScriptService.server.Player.PlayerService,
	ServerScriptService.server.Profile.ProfileService,
	ServerScriptService.server.Round.RoundService,
	ServerScriptService.server.Seed.Seed,
	ServerScriptService.server.Snapshot.SnapshotService,
	ServerScriptService.server.Vital.Vital,
	ServerScriptService.server.Vital.VitalService,
	ServerScriptService.server.Weapon.Equipment,
	ServerScriptService.server.Weapon.Gun,
	ServerScriptService.server.Weapon.WeaponService,
	ServerScriptService.server.Zone.Zone,
	ServerScriptService.server.Zone.ZoneService,
} :: { ModuleScript }
