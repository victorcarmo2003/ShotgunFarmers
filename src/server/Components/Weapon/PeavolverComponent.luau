local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local GetGun = require(ReplicatedStorage.Shared.Utils.GetGun)

local PeavolverComponent =	Modux.Component("PeavolverComponent"):Tag("Peavolver"):ClassName("Instance"):Extend("GunMixin"):Import("HitService")
type Self = typeof(PeavolverComponent)

PeavolverComponent.Shoot = function(
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

	local pelletDirection = self:RandomSpread(direction, self:GetEffectiveSpread(Shooter, isAiming))
	local claim = claimedPellets[1]
	if claim then
		local hit, targetPlayer, hitPart =
			self.HitService:ResolvePellet(Shooter, origin, pelletDirection, claim.TargetID, claim.HitPart, timestamp)
		if hit and targetPlayer then
			table.insert(confirmedHits, { Player = targetPlayer, HitPart = hitPart :: number })
		end
	end
	self:TryPlant(origin, pelletDirection, Shooter)

	self:ConsumeAndReplicateAmmo(Equipment)
	self:PlayShootSound(Shooter, self.ShootSoundName)

	return confirmedHits
end

PeavolverComponent:OnStart(function(self)
	local gunData = GetGun:GetByName("Peavolver")
	if not gunData then
		return
	end
	self.Damage = gunData.Damage :: number
	self.FireRate = gunData.FireRate :: number
	self.Spread = gunData.Spread :: number
	self.ShootAmount = 1 :: number
	self.Knockback = gunData.Knockback :: number
	self.ShootSoundName = gunData.ShootSound :: string
	self.GunName = "Peavolver" :: string
	self.DrawTime = gunData.DrawTime :: number?
end)

PeavolverComponent:OnDestroy(function(self) end)

return PeavolverComponent
