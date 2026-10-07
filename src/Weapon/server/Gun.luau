--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local WeaponSounds = require(ReplicatedStorage.shared.Weapon.WeaponSounds)
local Lync = require(ReplicatedStorage.Packages.Lync)
local GunRules = require(ServerScriptService.server.Weapon.GunRules)
local Modux = require(ServerScriptService.server.Modux)

export type Pellet = { TargetID: number, HitPart: number }
export type Hit = { Player: Player, HitPart: number, Distance: number }

const MELEE_HITBOX = 3.5
const PLANT_INTERVAL = 0.45

const Gun = Modux.Component("Gun", { Tag = "Gun", Require = { "HitService", "IDService", "NetService" } })

function Gun:Setup()
	const attribute = self.Instance:GetAttribute("GunName")
	const gunName = if type(attribute) == "string" then attribute else ""

	self.GunName = gunName :: string
	self.Stats = GetGun.ByName(gunName) :: GetGun.GunData?

	self.LastShoot = 0 :: number
	self.LastPlant = 0 :: number
end

function Gun:Data(): GetGun.GunData
	const stats = self.Stats
	if not stats then
		error(`[Gun] "{self.GunName}" nao existe em GunsData`)
	end

	return stats
end

function Gun:CanShoot(shooter: Player, ammo: number, stamp: number?): (boolean, string?)
	const stats = self.Stats
	if not stats then
		return false, "UnknownGun"
	end

	const equipment = self.Components.Equipment:Get(shooter)
	const drawEndsAt = if equipment then equipment:DrawEndsAt() else 0
	const now = workspace:GetServerTimeNow()

	return GunRules.CanShoot(stats, ammo, self.LastShoot, drawEndsAt, now, stamp or now)
end

function Gun:MarkShot(stamp: number)
	self.LastShoot = stamp
end

function Gun:CanPlant(): boolean
	const now = os.clock()
	if now - self.LastPlant < PLANT_INTERVAL then
		return false
	end

	self.LastPlant = now
	return true
end

function Gun:PlaySound(shooter: Player)
	const stats = self.Stats
	if not stats or WeaponSounds.ShootName(self.GunName) == "" or not self.Dependencies.NetService:IsRunning() then
		return
	end

	self.Libs.Net.Weapon.ShotSound:fireClient(Lync.except(shooter), {
		ShooterID = self.Dependencies.IDService:GetPlayerID(shooter),
		GunID = stats.ID,
	})
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
	const plants = self:CanPlant() and GunRules.RollSeed(self.GunName)

	for index = 1, stats.Bullets do
		const pelletDirection = GunRules.RandomSpread(direction, spread)

		if index <= claimed then
			const pellet = pellets[index]
			const confirmed, target, hitPart, distance = self.Dependencies.HitService:ResolvePellet(
				shooter,
				origin,
				pelletDirection,
				pellet.TargetID,
				pellet.HitPart,
				timestamp,
				stats.Range,
				nil
			)
			if confirmed and target then
				table.insert(hits, {
					Player = target,
					HitPart = hitPart or pellet.HitPart,
					Distance = distance or 0,
				})
			end
		end

		if plants then
			GunRules.TryPlant(shooter, origin, pelletDirection, self.GunName, stats.Range)
		end
	end

	self:PlaySound(shooter)

	return hits
end

function Gun:Strike(shooter: Player, origin: Vector3, direction: Vector3, pellets: { Pellet }, timestamp: number): { Hit }
	const hits: { Hit } = {}

	const stats = self.Stats
	const pellet = pellets[1]
	if not stats or not pellet then
		return hits
	end

	const confirmed, target, hitPart, distance = self.Dependencies.HitService:ResolvePellet(
		shooter,
		origin,
		direction,
		pellet.TargetID,
		pellet.HitPart,
		timestamp,
		stats.Range,
		MELEE_HITBOX
	)
	if confirmed and target then
		table.insert(hits, { Player = target, HitPart = hitPart or pellet.HitPart, Distance = distance or 0 })
	end

	return hits
end

function Gun:Spray(shooter: Player, origin: Vector3, direction: Vector3, timestamp: number): { Hit }
	const stats = self.Stats
	if not stats then
		return {}
	end

	if self:CanPlant() and GunRules.RollSeed(self.GunName) then
		GunRules.TryPlant(shooter, origin, direction, self.GunName, stats.Range)
	end

	return self.Dependencies.HitService:ConeTargets(shooter, origin, direction, stats.Range, stats.Spread, timestamp)
end

Gun:OnInit(function(self)
	self:Setup()

	if not self.Stats then
		warn(`[Gun] instancia "{self.Instance.Name}" sem GunName valido (atributo: "{self.GunName}")`)
	end
end)

return Gun
