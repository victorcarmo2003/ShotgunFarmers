--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local GunRules = require(ServerScriptService.server.Weapon.GunRules)
local Modux = require(ServerScriptService.server.Modux)

export type Pellet = { TargetID: number, HitPart: number }
export type Hit = { Player: Player, HitPart: number }

const Gun = Modux.Component("Gun", { Tag = "Gun", Require = { "HitService" } })

function Gun:Setup()
	const attribute = self.Instance:GetAttribute("GunName")
	const gunName = if type(attribute) == "string" then attribute else ""

	self.GunName = gunName :: string
	self.Stats = GetGun.ByName(gunName) :: GetGun.GunData?

	self.LastShoot = 0 :: number
end

function Gun:Data(): GetGun.GunData
	const stats = self.Stats
	if not stats then
		error(`[Gun] "{self.GunName}" nao existe em GunsData`)
	end

	return stats
end

function Gun:CanShoot(shooter: Player, ammo: number): (boolean, string?)
	const stats = self.Stats
	if not stats then
		return false, "UnknownGun"
	end

	const equipment = self.Components.Equipment:Get(shooter)
	const drawEndsAt = if equipment then equipment:DrawEndsAt() else 0

	return GunRules.CanShoot(stats, ammo, self.LastShoot, drawEndsAt, workspace:GetServerTimeNow())
end

function Gun:Shoot(
	shooter: Player,
	origin: Vector3,
	direction: Vector3,
	pellets: { Pellet },
	timestamp: number,
	isAiming: boolean
): { Hit }
	const hits: { Hit } = {}

	const stats = self.Stats
	if not stats then
		return hits
	end

	const spread = GunRules.EffectiveSpread(shooter, stats.Spread, isAiming)

	const claimed = math.min(#pellets, stats.Bullets)

	for index = 1, stats.Bullets do
		const pelletDirection = GunRules.RandomSpread(direction, spread)

		if index <= claimed then
			const pellet = pellets[index]
			const confirmed, target, hitPart = self.Dependencies.HitService:ResolvePellet(
				shooter,
				origin,
				pelletDirection,
				pellet.TargetID,
				pellet.HitPart,
				timestamp
			)
			if confirmed and target then
				table.insert(hits, { Player = target, HitPart = hitPart or pellet.HitPart })
			end
		end

		GunRules.TryPlant(shooter, origin, pelletDirection, self.GunName)
	end

	self.LastShoot = workspace:GetServerTimeNow()

	const equipment = self.Components.Equipment:Get(shooter)
	if equipment then
		equipment:ConsumeAmmo(1)
		GunRules.PlayShootSound(shooter, stats.ShootSound, equipment.Visual)
	end

	return hits
end

Gun:OnInit(function(self)
	self:Setup()

	if not self.Stats then
		warn(`[Gun] instancia "{self.Instance.Name}" sem GunName valido (atributo: "{self.GunName}")`)
	end
end)

return Gun
