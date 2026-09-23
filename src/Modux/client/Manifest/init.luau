--!strict

local StarterPlayer = game:GetService("StarterPlayer")
local AdminController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.AdminController)
local MusicController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.MusicController)
local CameraController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.CameraController)
local ColorCorrectionController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ColorCorrectionController)
local DeathCameraController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.DeathCameraController)
local FOVController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.FOVController)
local UnlockCameraController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.UnlockCameraController)
local AnimateController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.AnimateController)
local MovementController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.MovementController)
local HitController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.HitController)
local ProjectileController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ProjectileController)
local InputController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.InputController)
local InterfaceController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.InterfaceController)
local SurfaceUIController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.SurfaceUIController)
local KillFeedController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.KillFeedController)
local NetController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.NetController)
local ProfileController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ProfileController)
local RoundController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.RoundController)
local SeedController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.SeedController)
local SnapshotController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.SnapshotController)
local VitalController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.VitalController)
local ArmsController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ArmsController)
local WeaponController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.WeaponController)

export type AllControllers = {
	AdminController: AdminController.Public,
	MusicController: MusicController.Public,
	CameraController: CameraController.Public,
	ColorCorrectionController: ColorCorrectionController.Public,
	DeathCameraController: DeathCameraController.Public,
	FOVController: FOVController.Public,
	UnlockCameraController: UnlockCameraController.Public,
	AnimateController: AnimateController.Public,
	MovementController: MovementController.Public,
	HitController: HitController.Public,
	ProjectileController: ProjectileController.Public,
	InputController: InputController.Public,
	InterfaceController: InterfaceController.Public,
	SurfaceUIController: SurfaceUIController.Public,
	KillFeedController: KillFeedController.Public,
	NetController: NetController.Public,
	ProfileController: ProfileController.Public,
	RoundController: RoundController.Public,
	SeedController: SeedController.Public,
	SnapshotController: SnapshotController.Public,
	VitalController: VitalController.Public,
	ArmsController: ArmsController.Public,
	WeaponController: WeaponController.Public,
}

export type AllComponents = {}

export type ComponentAccess = {}

return {}
