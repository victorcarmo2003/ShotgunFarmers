--!strict

local StarterPlayer = game:GetService("StarterPlayer")
local AdminController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.AdminController)
local FunnelController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.FunnelController)
local MusicController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.MusicController)
local BotController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.BotController)
local TeamOutlineController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.TeamOutlineController)
local CameraController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.CameraController)
local ColorCorrectionController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ColorCorrectionController)
local DeathCameraController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.DeathCameraController)
local FOVController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.FOVController)
local MenuEffectsController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.MenuEffectsController)
local UnlockCameraController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.UnlockCameraController)
local CareerController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.CareerController)
local AnimateController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.AnimateController)
local MovementController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.MovementController)
local DamageNumberController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.DamageNumberController)
local HitController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.HitController)
local ProjectileController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ProjectileController)
local InputController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.InputController)
local InterfaceController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.InterfaceController)
local SurfaceUIController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.SurfaceUIController)
local KillFeedController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.KillFeedController)
local KillMedalController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.KillMedalController)
local OnlineController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.OnlineController)
local GameStateController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.GameStateController)
local LobbyController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.LobbyController)
local MatchmakingController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.MatchmakingController)
local NetController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.NetController)
local OptionsController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.OptionsController)
local SensitivityController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.SensitivityController)
local PartyController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.PartyController)
local PracticeController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.PracticeController)
local ProfileController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ProfileController)
local RankController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.RankController)
local RoundController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.RoundController)
local VoteController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.VoteController)
local RestockController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.RestockController)
local SeedController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.SeedController)
local ShopController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ShopController)
local SnapshotController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.SnapshotController)
local LeaderstatsController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.LeaderstatsController)
local VitalController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.VitalController)
local ArmsController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ArmsController)
local PreloadController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.PreloadController)
local ScopeController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ScopeController)
local ThrowableController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.ThrowableController)
local VFXController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.VFXController)
local WeaponController = require(StarterPlayer.StarterPlayerScripts.client.ModuxTypes.WeaponController)

export type AllControllers = {
	AdminController: AdminController.Public,
	FunnelController: FunnelController.Public,
	MusicController: MusicController.Public,
	BotController: BotController.Public,
	TeamOutlineController: TeamOutlineController.Public,
	CameraController: CameraController.Public,
	ColorCorrectionController: ColorCorrectionController.Public,
	DeathCameraController: DeathCameraController.Public,
	FOVController: FOVController.Public,
	MenuEffectsController: MenuEffectsController.Public,
	UnlockCameraController: UnlockCameraController.Public,
	CareerController: CareerController.Public,
	AnimateController: AnimateController.Public,
	MovementController: MovementController.Public,
	DamageNumberController: DamageNumberController.Public,
	HitController: HitController.Public,
	ProjectileController: ProjectileController.Public,
	InputController: InputController.Public,
	InterfaceController: InterfaceController.Public,
	SurfaceUIController: SurfaceUIController.Public,
	KillFeedController: KillFeedController.Public,
	KillMedalController: KillMedalController.Public,
	OnlineController: OnlineController.Public,
	GameStateController: GameStateController.Public,
	LobbyController: LobbyController.Public,
	MatchmakingController: MatchmakingController.Public,
	NetController: NetController.Public,
	OptionsController: OptionsController.Public,
	SensitivityController: SensitivityController.Public,
	PartyController: PartyController.Public,
	PracticeController: PracticeController.Public,
	ProfileController: ProfileController.Public,
	RankController: RankController.Public,
	RoundController: RoundController.Public,
	VoteController: VoteController.Public,
	RestockController: RestockController.Public,
	SeedController: SeedController.Public,
	ShopController: ShopController.Public,
	SnapshotController: SnapshotController.Public,
	LeaderstatsController: LeaderstatsController.Public,
	VitalController: VitalController.Public,
	ArmsController: ArmsController.Public,
	PreloadController: PreloadController.Public,
	ScopeController: ScopeController.Public,
	ThrowableController: ThrowableController.Public,
	VFXController: VFXController.Public,
	WeaponController: WeaponController.Public,
}

export type AllComponents = {}

export type ComponentAccess = {}

return {}
