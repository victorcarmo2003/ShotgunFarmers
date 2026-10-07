--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Ballistics = require(ReplicatedStorage.shared.Weapon.Ballistics)
local Body = require(ReplicatedStorage.shared.Hit.Body)
local HitNet = require(ReplicatedStorage.shared.Hit.Net)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local Lync = require(ReplicatedStorage.Packages.Lync)
local Modux = require(ServerScriptService.server.Modux)

export type FireRequest = {
	Origin: Vector3,
	Direction: Vector3,
	Pellets: { HitNet.Pellet },
	IsAiming: boolean,
	TimeStamp: number,
}

export type FireReply = {
	Accepted: boolean,
	Hits: number,
}

export type FireBudget = {
	Tokens: number,
	At: number,
}

export type ResolvedHit = { Player: Player, HitPart: number, Distance: number }

const HITBOX_RADIUS = 4.5
const CONE_BODY_RADIUS = 2
const ORIGIN_TOLERANCE = 10

const TIMESTAMP_AHEAD = 0.25
const TIMESTAMP_BEHIND = 1

const FIRES_PER_SECOND = 20
const FIRE_BURST = 12

const MAX_REPLY_HITS = 12
const MIN_TRAVEL_DELAY = 0.02

const REJECTED: FireReply = { Accepted = false, Hits = 0 }

const raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

const HitService = Modux.Service("HitService", {
	Require = {
		"GameStateService",
		"IDService",
		"MatchStatsService",
		"NetService",
		"PlayerService",
		"SnapshotService",
		"TeamService",
	},
	Priority = 500,
})

function HitService:Setup()
	self.Budget = {} :: { [Player]: FireBudget }
	self.Burned = self.Libs.Signal.new() :: SignalLib.Signal<Player, Player, string>
end

local function closestPointOnRay(origin: Vector3, direction: Vector3, maxDistance: number, point: Vector3): Vector3
	const along = math.clamp((point - origin):Dot(direction), 0, maxDistance)
	return origin + direction * along
end

local function rootPart(character: Model?): BasePart?
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

function HitService:SpendFireToken(player: Player): boolean
	const now = os.clock()
	const budget = self.Budget[player]
	if not budget then
		self.Budget[player] = { Tokens = FIRE_BURST - 1, At = now }
		return true
	end

	const tokens = math.min(budget.Tokens + (now - budget.At) * FIRES_PER_SECOND, FIRE_BURST)
	budget.At = now

	if tokens < 1 then
		budget.Tokens = tokens
		return false
	end

	budget.Tokens = tokens - 1
	return true
end

function HitService:DealDamage(shooter: Player, target: Player, damage: number): (boolean, boolean)
	const vital = self.Components.Vital:Get(target)
	if not vital or not vital.Alive then
		return false, false
	end

	const dealt = math.min(damage, vital.Health + vital.Armor)
	const killed = not vital:TakeDamage(damage)
	self.Dependencies.MatchStatsService:RecordDamage(shooter, target, dealt)
	return true, killed
end

function HitService:ApplyKnockback(root: BasePart, direction: Vector3, force: number)
	if direction.Magnitude < 0.001 or force <= 0 then
		return
	end

	root:ApplyImpulse(direction.Unit * force * root.AssemblyMass)
end

function HitService:Announce(shooter: Player, victim: Player, gunName: string, isHeadshot: boolean)
	if not self.Dependencies.NetService:IsRunning() then
		return
	end

	self.Libs.Net.KillFeed.Kill:fireClient(self.Dependencies.NetService.Audience, {
		ShooterID = self.Dependencies.IDService:GetPlayerID(shooter),
		VictimID = self.Dependencies.IDService:GetPlayerID(victim),
		GunName = gunName,
		IsHeadshot = isHeadshot,
	})
end

function HitService:BroadcastShot(shooter: Player, gunData: GetGun.GunData, origin: Vector3, direction: Vector3)
	if gunData.FireMode == "Melee" or not self.Dependencies.NetService:IsRunning() then
		return
	end

	self.Libs.Net.Hit.Shot:fireClient(Lync.except(shooter), {
		ShooterID = self.Dependencies.IDService:GetPlayerID(shooter),
		GunID = gunData.ID,
		Origin = origin,
		Direction = direction,
	})
end

function HitService:ResolvePellet(
	shooter: Player,
	origin: Vector3,
	direction: Vector3,
	claimedTargetID: number,
	claimedHitPart: number,
	timestamp: number,
	range: number,
	hitbox: number?
): (boolean, Player?, number?, number?)
	if direction.Magnitude < 0.5 or range <= 0 then
		return false, nil, nil, nil
	end
	const unitDirection = direction.Unit

	const target = self.Dependencies.IDService:GetPlayerFromID(claimedTargetID)
	if not target or target == shooter then
		return false, nil, nil, nil
	end

	const shooterCharacter = shooter.Character
	const targetCharacter = target.Character
	const targetRoot = rootPart(targetCharacter)
	if not shooterCharacter or not targetCharacter or not targetRoot then
		return false, nil, nil, nil
	end

	const rewound = self.Dependencies.SnapshotService:GetRewoundPosition(claimedTargetID, timestamp)
		or targetRoot.Position

	raycastParams.FilterDescendantsInstances = { shooterCharacter, targetCharacter }
	const obstruction = workspace:Raycast(origin, unitDirection * range, raycastParams)
	const maxDistance = if obstruction then obstruction.Distance else range

	const closest = closestPointOnRay(origin, unitDirection, maxDistance, rewound)
	if (closest - rewound).Magnitude > (hitbox or HITBOX_RADIUS) then
		return false, nil, nil, nil
	end

	return true, target, claimedHitPart, (closest - origin).Magnitude
end

function HitService:ConeTargets(
	shooter: Player,
	origin: Vector3,
	direction: Vector3,
	range: number,
	angle: number,
	timestamp: number
): { ResolvedHit }
	const hits: { ResolvedHit } = {}
	const shooterCharacter = shooter.Character
	if not shooterCharacter or direction.Magnitude < 0.5 then
		return hits
	end
	const unitDirection = direction.Unit
	const halfAngle = math.rad(angle)

	for _, target in Players:GetPlayers() do
		if target == shooter then
			continue
		end

		const vital = self.Components.Vital:Get(target)
		const targetCharacter = target.Character
		const targetRoot = rootPart(targetCharacter)
		if not vital or not vital.Alive or not targetCharacter or not targetRoot then
			continue
		end

		const targetID = self.Dependencies.IDService:GetPlayerID(target)
		const rewound = self.Dependencies.SnapshotService:GetRewoundPosition(targetID, timestamp)
			or targetRoot.Position
		const offset = rewound - origin
		const distance = offset.Magnitude
		if distance > range + CONE_BODY_RADIUS then
			continue
		end

		if distance > CONE_BODY_RADIUS then
			const tolerance = math.atan(CONE_BODY_RADIUS / distance)
			if unitDirection:Dot(offset.Unit) < math.cos(math.min(halfAngle + tolerance, math.pi)) then
				continue
			end
		end

		raycastParams.FilterDescendantsInstances = { shooterCharacter, targetCharacter }
		if workspace:Raycast(origin, offset, raycastParams) then
			continue
		end

		table.insert(hits, { Player = target, HitPart = Body.Torso, Distance = distance })
	end

	return hits
end

function HitService:HitDamage(gunData: GetGun.GunData, hit: ResolvedHit): number
	local damage = gunData.Damage
	if hit.HitPart == Body.Head then
		damage *= gunData.HeadshotMultiplier
	end

	if gunData.FireMode == "Hitscan" then
		damage *= GetGun.RangeFalloff(gunData, hit.Distance)
	end

	return math.max(math.round(damage), 1)
end

function HitService:ApplyHit(shooter: Player, hit: ResolvedHit, gunData: GetGun.GunData, gunName: string, origin: Vector3)
	const dealt, killed = self:DealDamage(shooter, hit.Player, self:HitDamage(gunData, hit))
	if not dealt then
		return
	end

	const victimRoot = rootPart(hit.Player.Character)
	if victimRoot then
		self:ApplyKnockback(victimRoot, victimRoot.Position - origin, gunData.Knockback)
	end

	if gunData.FireMode == "Cone" and not killed then
		self.Burned:Fire(shooter, hit.Player, gunName)
	end

	if killed then
		const isHeadshot = hit.HitPart == Body.Head
		self.Dependencies.MatchStatsService:RecordKill(shooter, hit.Player, isHeadshot)
		self:Announce(shooter, hit.Player, gunName, isHeadshot)
	end
end

function HitService:ProcessFire(request: FireRequest, shooter: Player): FireReply
	if not self.Dependencies.GameStateService:Can("Combat") then
		return REJECTED
	end

	if not self:SpendFireToken(shooter) then
		return REJECTED
	end

	const now = workspace:GetServerTimeNow()
	const drift = now - request.TimeStamp
	if drift < -TIMESTAMP_AHEAD or drift > TIMESTAMP_BEHIND then
		return REJECTED
	end

	const vital = self.Components.Vital:Get(shooter)
	if not vital or not vital.Alive then
		return REJECTED
	end

	const root = rootPart(shooter.Character)
	if not root then
		return REJECTED
	end

	if (request.Origin - root.Position).Magnitude > ORIGIN_TOLERANCE then
		return REJECTED
	end

	if request.Direction.Magnitude < 0.5 then
		return REJECTED
	end
	const direction = request.Direction.Unit

	const equipment = self.Components.Equipment:Get(shooter)
	if not equipment then
		return REJECTED
	end

	if now < equipment:DrawEndsAt() then
		return REJECTED
	end

	const weaponInstance, gunName = equipment:ActiveGun()
	if not weaponInstance or not gunName then
		return REJECTED
	end

	const gun = self.Components.Gun:Get(weaponInstance)
	if not gun then
		return REJECTED
	end

	const gunData = gun:Data()
	const mode = gunData.FireMode
	if mode == "Projectile" or mode == "Throw" then
		return REJECTED
	end

	if not gun:CanShoot(shooter, equipment:ActiveAmmo(), request.TimeStamp) then
		return REJECTED
	end

	if GetGun.UsesAmmo(gunData) and not equipment:ConsumeAmmo(1) then
		return REJECTED
	end
	gun:MarkShot(request.TimeStamp)
	self:BroadcastShot(shooter, gunData, request.Origin, direction)

	local hits: { ResolvedHit }
	if mode == "Melee" then
		hits = gun:Strike(shooter, request.Origin, direction, request.Pellets, request.TimeStamp)
	elseif mode == "Cone" then
		hits = gun:Spray(shooter, request.Origin, direction, request.TimeStamp)
	else
		hits = gun:Shoot(
			shooter,
			request.Origin,
			direction,
			request.Pellets,
			request.TimeStamp,
			request.IsAiming == true
		)
	end

	local landed = 0
	for _, hit in hits do
		if self.Dependencies.TeamService:SameTeam(shooter, hit.Player) then
			continue
		end

		const targetVital = self.Components.Vital:Get(hit.Player)
		if not targetVital or not targetVital.Alive then
			continue
		end
		landed += 1

		const travel = if mode == "Hitscan" then Ballistics.Travel(gunData, hit.Distance) else 0
		if travel > MIN_TRAVEL_DELAY then
			task.delay(travel, function()
				self:ApplyHit(shooter, hit, gunData, gunName, request.Origin)
			end)
		else
			self:ApplyHit(shooter, hit, gunData, gunName, request.Origin)
		end
	end

	self:ApplyKnockback(root, -direction, gunData.Knockback)
	return { Accepted = true, Hits = math.min(landed, MAX_REPLY_HITS) }
end

HitService:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Hit.Fire:onServer(function(request, player): FireReply
		return self:ProcessFire(request, player)
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self.Budget[player] = nil
	end)
end)

return HitService
