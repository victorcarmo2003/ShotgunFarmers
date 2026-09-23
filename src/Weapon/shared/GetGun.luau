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
	| "Grenade"
	| "Bananarang"
	| "Lemonade"
	| "Moolotov"
	| "Onionnade"
	| "Pinapple"

export type AmmoType = "Single" | "Multi" | "Area"

export type PoseKind = "Firearm" | "Melee" | "Throwable"

export type AimType = "Spread" | "Default"

export type WeldPart = "RightArm" | "Torso"

export type GunData = {
	ID: number,
	DisplayName: string,
	BulletType: AmmoType,
	Amount: number,
	Damage: number,
	Spread: number,
	Bullets: number,
	FireRate: number,
	ImageID: string,
	Knockback: number,

	AnimationSet: string,
	PoseKind: PoseKind,

	DrawTime: number?,
	ShootSound: string,
	SeedModel: string,
	AimType: AimType?,
	DiscardWhenEmpty: boolean?,
	WeldTo: WeldPart?,
}

const ALL = Guns :: { [string]: GunData }

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

return GetGun
