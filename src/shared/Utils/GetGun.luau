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

export type AmmoType = "Single" | "Multi" | "Area"

export type WeaponAnimationSet = {
	Idle: string,
	Aim: string,
	Shoot: string,
}

export type WeaponAnimations = {
	-- Toca no rig do viewmodel (braços esticados por RigBuilder.ARM_SIZE, só o dono vê).
	Viewmodel: WeaponAnimationSet,
	-- Toca no Animator do Humanoid REAL (proporção normal) -- replica pra 3ª pessoa
	-- automaticamente, ver ArmsController.EquipCharacterPose.
	Character: WeaponAnimationSet,
}

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
	Animations: WeaponAnimations,
	-- Name do Sound dentro de ReplicatedStorage.Assets.Sounds tocado a cada tiro (ver
	-- GunMixin.PlayShootSound) -- "" quando a arma ainda não tem som gravado.
	ShootSound: string,
	-- Name do Model dentro de ReplicatedStorage.Assets.Seeds clonado por SeedComponent
	-- ao germinar (ver GunMixin.PlantAt).
	SeedModel: string,
	-- Estilo de crosshair (Interface/GameComponents/Crosshair.luau) -- "Spread" mostra
	-- as 4 marcas que se afastam com o spread efetivo, "Default" é o "+" estático.
	-- Opcional: arma sem AimType (as 7 ainda sem componente) cai pro "Default".
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
