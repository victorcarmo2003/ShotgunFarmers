--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local Vide = require(ReplicatedStorage.Packages.Vide)
local AnimationSetLoader = require(StarterPlayer.StarterPlayerScripts.client.Weapon.AnimationSetLoader)
local PoseMachine = require(StarterPlayer.StarterPlayerScripts.client.Weapon.PoseMachine)

export type Public = {
	Animator: Animator?,
	CharacterAnimator: Animator?,
	CharacterGuiConnection: RBXScriptConnection?,
	CharacterTracks: AnimationSetLoader.TrackSet?,
	CurrentOffset: CFrame,
	EquippedSlot: number?,
	EquippedWeaponID: number?,
	IsAiming: Vide.Source<boolean>,
	PoseMachine: PoseMachine.PoseMachine?,
	PumpMarkerConnections: { RBXScriptConnection },
	Rig: Model?,
	RiggedCharacter: Model?,
	ViewmodelTracks: AnimationSetLoader.TrackSet?,
	WeaponModel: Model?,
	Setup: (self: Public) -> (),
	ClearViewmodel: (self: Public) -> (),
	ClearCharacterPose: (self: Public) -> (),
	ClearRig: (self: Public) -> (),
	EquipViewmodel: (self: Public, gunData: GetGun.GunData?) -> (),
	EquipCharacterPose: (self: Public, gunData: GetGun.GunData?) -> (),
	DrawSeconds: (self: Public, gunData: GetGun.GunData) -> number,
	EquipCurrentGun: (self: Public) -> (),
	RebuildRig: (self: Public, character: Model) -> (),
	SetAiming: (self: Public, aiming: boolean) -> (),
	PlayShoot: (self: Public) -> (),
	PlayReload: (self: Public) -> (),
	PlayAttack: (self: Public) -> (),
	BeginThrow: (self: Public) -> (),
	ReleaseThrow: (self: Public) -> (),
	GetPoseState: (self: Public) -> PoseMachine.PoseState?,
	GetMuzzlePosition: (self: Public) -> Vector3?,
	OnPumpMarker: (self: Public) -> (),
	StepCharacter: (self: Public) -> (),
	StepLoadout: (self: Public) -> (),
	FollowCamera: (self: Public, deltaTime: number) -> (),
	BindKeys: (self: Public) -> (),
}

return {}
