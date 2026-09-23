--!strict

local StarterPlayer = game:GetService("StarterPlayer")

return {
	StarterPlayer.StarterPlayerScripts.client.Admin.AdminController,
	StarterPlayer.StarterPlayerScripts.client.Audio.MusicController,
	StarterPlayer.StarterPlayerScripts.client.Camera.CameraController,
	StarterPlayer.StarterPlayerScripts.client.Camera.ColorCorrectionController,
	StarterPlayer.StarterPlayerScripts.client.Camera.DeathCameraController,
	StarterPlayer.StarterPlayerScripts.client.Camera.FOVController,
	StarterPlayer.StarterPlayerScripts.client.Camera.UnlockCameraController,
	StarterPlayer.StarterPlayerScripts.client.Character.AnimateController,
	StarterPlayer.StarterPlayerScripts.client.Character.MovementController,
	StarterPlayer.StarterPlayerScripts.client.Hit.HitController,
	StarterPlayer.StarterPlayerScripts.client.Hit.ProjectileController,
	StarterPlayer.StarterPlayerScripts.client.Input.InputController,
	StarterPlayer.StarterPlayerScripts.client.Interface.InterfaceController,
	StarterPlayer.StarterPlayerScripts.client.Interface.SurfaceUIController,
	StarterPlayer.StarterPlayerScripts.client.KillFeed.KillFeedController,
	StarterPlayer.StarterPlayerScripts.client.Net.NetController,
	StarterPlayer.StarterPlayerScripts.client.Profile.ProfileController,
	StarterPlayer.StarterPlayerScripts.client.Round.RoundController,
	StarterPlayer.StarterPlayerScripts.client.Seed.SeedController,
	StarterPlayer.StarterPlayerScripts.client.Snapshot.SnapshotController,
	StarterPlayer.StarterPlayerScripts.client.Vital.VitalController,
	StarterPlayer.StarterPlayerScripts.client.Weapon.ArmsController,
	StarterPlayer.StarterPlayerScripts.client.Weapon.WeaponController,
} :: { ModuleScript }
