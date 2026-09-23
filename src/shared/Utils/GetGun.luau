local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guns = require(ReplicatedStorage.Shared.Datas.Guns)

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
	| "Hoe"
	| "Grenade"

export type AmmoType = "Single" | "Multi" | "Area"

export type PoseKind = "Firearm" | "Melee" | "Throwable"

export type AimType = "Spread" | "Default"

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
}

local GetGun = {}
GetGun.AllGuns = Guns :: { [GunNames]: GunData }

GetGun.GetAll = function(self)
	return self.AllGuns
end

GetGun.GetByID = function(self, id: number): GunData?
	for _, gun in self.AllGuns do
		if gun.ID == id then
			return gun
		end
	end
	return nil
end

GetGun.GetByName = function(self, name: GunNames): GunData?
	return self.AllGuns[name]
end

return GetGun
