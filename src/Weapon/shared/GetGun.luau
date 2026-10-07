--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guns = require(ReplicatedStorage.shared.Weapon.GunsData)

export type GunNames =
	"Shotgun"
	| "Sniperagus"
	| "Carrocket"
	| "Peavolver"
	| "Gromato Launcher"
	| "Chilli Thrower"
	| "M6Bean"
	| "WatermeLMG"
	| "Double Cob"
	| "Snipine"
	| "Uzichinni"
	| "Raygun"
	| "Strawborry"
	| "Hoe"
	| "Shovel"
	| "Bananarang"
	| "Lemonade"
	| "Moolotov"
	| "Onionnade"
	| "Pinapple"

export type PoseKind = "Firearm" | "Melee" | "Throwable"

export type AimType = "Spread" | "Default"

export type WeldPart = "RightArm" | "Torso"

export type FireMode = "Hitscan" | "Projectile" | "Cone" | "Melee" | "Throw"

export type ScopeData = { Fov: number, Sensitivity: number?, Lens: string?, HousingColor: Color3? }

export type GunData = {
	ID: number,
	DisplayName: string,
	Amount: number,
	Damage: number,
	Spread: number,
	Bullets: number,
	FireRate: number,
	ImageID: string,
	Knockback: number,

	AnimationSet: string,
	PoseKind: PoseKind,

	HeadshotMultiplier: number,
	Range: number,
	FireMode: FireMode,

	DrawTime: number?,
	SeedModel: string,
	SeedChance: number?,
	BulletSpeed: number?,
	BulletDrop: number?,
	HitDelay: number?,
	AimType: AimType?,
	DiscardWhenEmpty: boolean?,
	WeldTo: WeldPart?,
	Disabled: boolean?,
	Scope: ScopeData?,
}

const ALL = Guns :: { [string]: GunData }

const FULL_DAMAGE_FRACTION = 0.6
const MIN_DAMAGE_FRACTION = 0.5

local GetGun = {}

GetGun.All = ALL

function GetGun.ByName(name: string): GunData?
	return ALL[name]
end

function GetGun.ByID(id: number): GunData?
	for _, gun in ALL do
		if gun.ID == id then
			return gun
		end
	end

	return nil
end

function GetGun.UsesAmmo(gunData: GunData): boolean
	return gunData.FireMode ~= "Melee"
end

function GetGun.RangeFalloff(gunData: GunData, distance: number): number
	const range = gunData.Range
	if range <= 0 then
		return 1
	end

	const fullUntil = range * FULL_DAMAGE_FRACTION
	if distance <= fullUntil then
		return 1
	end

	const alpha = math.clamp((distance - fullUntil) / (range - fullUntil), 0, 1)
	return 1 + (MIN_DAMAGE_FRACTION - 1) * alpha
end

return GetGun
