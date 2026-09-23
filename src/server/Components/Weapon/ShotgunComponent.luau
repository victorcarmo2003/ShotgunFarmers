local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local GetGun = require(ReplicatedStorage.Shared.Utils.GetGun)

local ShotgunComponent =
	Modux.Component("ShotgunComponent"):Tag("Shotgun"):ClassName("Instance"):Extend("GunMixin"):Import("HitService")
type Self = typeof(ShotgunComponent)

ShotgunComponent.Shoot = function(
	self: Self,
	Shooter: Player,
	Equipment: any,
	origin: Vector3,
	direction: Vector3,
	claimedPellets: { { TargetID: number, HitPart: number } },
	timestamp: number,
	isAiming: boolean
): { { Player: Player, HitPart: number } }
	local confirmedHits: { { Player: Player, HitPart: number } } = {}

	local spread = self:GetEffectiveSpread(Shooter, isAiming)

	local pelletsToCheck = math.min(#claimedPellets, self.ShootAmount)
	for i = 1, self.ShootAmount do
		local pelletDirection = self:RandomSpread(direction, spread)

		if i <= pelletsToCheck then
			local claim = claimedPellets[i]
			local hit, targetPlayer, hitPart = self.HitService:ResolvePellet(
				Shooter,
				origin,
				pelletDirection,
				claim.TargetID,
				claim.HitPart,
				timestamp
			)
			if hit and targetPlayer then
				table.insert(confirmedHits, { Player = targetPlayer, HitPart = hitPart :: number })
			end
		end

		self:TryPlant(origin, pelletDirection, Shooter)
	end

	self:ConsumeAndReplicateAmmo(Equipment)
	self:PlayShootSound(Shooter, self.ShootSoundName)

	return confirmedHits
end

ShotgunComponent:OnStart(function(self)
	local gunData = GetGun:GetByName("Shotgun")
	if not gunData then
		return
	end
	self.Damage = gunData.Damage :: number
	self.FireRate = gunData.FireRate :: number
	self.Spread = gunData.Spread :: number
	self.ShootAmount = gunData.Bullets :: number
	self.Knockback = gunData.Knockback :: number
	self.ShootSoundName = gunData.ShootSound :: string
	self.GunName = "Shotgun" :: string
	self.DrawTime = gunData.DrawTime :: number?
end)

ShotgunComponent:OnDestroy(function(self) end)

return ShotgunComponent
