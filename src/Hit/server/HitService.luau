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
local BotSettings = require(ReplicatedStorage.shared.Bot.BotSettings)
local BotTypes = require(ServerScriptService.server.Bot.BotTypes)
local Modux = require(ServerScriptService.server.Modux)

type Fighter = BotTypes.Fighter

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

export type ResolvedHit = { Target: Fighter, HitPart: number, Distance: number }

type Candidate = { Fighter: Fighter, ID: number, Root: Vector3, Character: Model? }

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
		"BotRegistryService",
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
	return BotTypes.Root(character)
end

function HitService:IDOf(fighter: Fighter): number
	const bot = BotTypes.AsBot(fighter)
	if bot then
		return bot.GameID
	end
	return self.Dependencies.IDService:GetPlayerID(fighter :: Player)
end

function HitService:IsAlive(fighter: Fighter): boolean
	const bot = BotTypes.AsBot(fighter)
	if bot then
		return bot.Alive
	end
	const vital = self.Components.Vital:Get(fighter :: Player)
	return vital ~= nil and vital.Alive
end

function HitService:Candidates(shooter: Fighter): { Candidate }
	const list: { Candidate } = {}
	for _, player in Players:GetPlayers() do
		if player == shooter or not self:IsAlive(player) then
			continue
		end
		const character = player.Character
		const root = rootPart(character)
		if character and root then
			table.insert(list, {
				Fighter = player,
				ID = self.Dependencies.IDService:GetPlayerID(player),
				Root = root.Position,
				Character = character,
			})
		end
	end

	for _, bot in self.Dependencies.BotRegistryService:All() do
		if bot ~= shooter and bot.Alive then
			table.insert(list, { Fighter = bot, ID = bot.GameID, Root = bot.Position, Character = nil })
		end
	end
	return list
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

function HitService:DealDamage(shooter: Fighter, target: Fighter, damage: number, isHeadshot: boolean?): (boolean, boolean)
	const position = BotTypes.Position(target)
	const bot = BotTypes.AsBot(target)
	if bot then
		if not bot.Alive then
			return false, false
		end
		const botDealt = math.min(damage, bot.Health + bot.Armor)
		self.Dependencies.MatchStatsService:RecordDamage(shooter, bot, botDealt)
		const _, botKilled = self.Dependencies.BotRegistryService:Damage(bot, damage)
		self:NotifyDealt(shooter, bot.GameID, position, botDealt, isHeadshot == true, botKilled)
		return true, botKilled
	end

	const player = target :: Player
	const vital = self.Components.Vital:Get(player)
	if not vital or not vital.Alive then
		return false, false
	end

	const dealt = math.min(damage, vital.Health + vital.Armor)
	const killed = not vital:TakeDamage(damage)
	self.Dependencies.MatchStatsService:RecordDamage(shooter, player, dealt)
	self:NotifyDamaged(shooter, player, dealt)
	const gameID = player:GetAttribute("GameID")
	self:NotifyDealt(shooter, if typeof(gameID) == "number" then gameID else 0, position, dealt, isHeadshot == true, killed)
	return true, killed
end

function HitService:NotifyDealt(shooter: Fighter, targetID: number, position: Vector3?, amount: number, isHeadshot: boolean, killed: boolean)
	const shooterPlayer = BotTypes.AsPlayer(shooter)
	const netService = self.Dependencies.NetService
	if not shooterPlayer or not position or amount <= 0 then
		return
	end
	if not netService:IsRunning() or not netService:IsReady(shooterPlayer) then
		return
	end

	self.Libs.Net.Hit.Dealt:fireClient(shooterPlayer, {
		TargetID = math.clamp(targetID, 0, 255),
		Position = position,
		Amount = math.clamp(math.round(amount), 0, 4095),
		Headshot = isHeadshot,
		Killed = killed,
	})
end

function HitService:NotifyDamaged(shooter: Fighter, target: Player, amount: number)
	const netService = self.Dependencies.NetService
	const shooterPosition = BotTypes.Position(shooter)
	if shooter == target or amount <= 0 or not shooterPosition then
		return
	end
	if not netService:IsRunning() or not netService:IsReady(target) then
		return
	end

	self.Libs.Net.Vital.Damaged:fireClient(target, {
		From = shooterPosition,
		Amount = math.clamp(math.round(amount), 0, 255),
	})
end

function HitService:ApplyKnockback(root: BasePart, direction: Vector3, force: number)
	if direction.Magnitude < 0.001 or force <= 0 then
		return
	end

	root:ApplyImpulse(direction.Unit * force * root.AssemblyMass)
end

function HitService:Announce(shooter: Fighter, victim: Fighter, gunName: string, isHeadshot: boolean)
	if not self.Dependencies.NetService:IsRunning() then
		return
	end

	self.Libs.Net.KillFeed.Kill:fireClient(self.Dependencies.NetService.Audience, {
		ShooterID = self:IDOf(shooter),
		VictimID = self:IDOf(victim),
		GunName = gunName,
		IsHeadshot = isHeadshot,
	})
end

function HitService:BroadcastShot(shooter: Fighter, gunData: GetGun.GunData, origin: Vector3, direction: Vector3)
	if gunData.FireMode == "Melee" or not self.Dependencies.NetService:IsRunning() then
		return
	end

	const player = BotTypes.AsPlayer(shooter)
	const audience = if player then Lync.except(player) else self.Dependencies.NetService.Audience
	self.Libs.Net.Hit.Shot:fireClient(audience, {
		ShooterID = self:IDOf(shooter),
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
	hitbox: number?,
	gunData: GetGun.GunData?
): (boolean, Fighter?, number?, number?)
	if direction.Magnitude < 0.5 or range <= 0 then
		return false, nil, nil, nil
	end
	const unitDirection = direction.Unit

	const shooterCharacter = shooter.Character
	if not shooterCharacter then
		return false, nil, nil, nil
	end

	local target: Fighter? = nil
	local current: Vector3? = nil
	const filter: { Instance } = { shooterCharacter }

	const bot = self.Dependencies.BotRegistryService:FromID(claimedTargetID)
	if bot then
		if bot.Alive then
			target = bot
			current = bot.Position
		end
	else
		const player = self.Dependencies.IDService:GetPlayerFromID(claimedTargetID)
		const targetCharacter = if player then player.Character else nil
		const targetRoot = rootPart(targetCharacter)
		if player and player ~= shooter and targetCharacter and targetRoot then
			target = player
			current = targetRoot.Position
			table.insert(filter, targetCharacter)
		end
	end

	if not target or not current then
		return false, nil, nil, nil
	end

	const rewindAt = if bot then timestamp - BotSettings.InterpolationDelay else timestamp
	const rewound: Vector3 = self.Dependencies.SnapshotService:GetRewoundPosition(claimedTargetID, rewindAt)
		or current :: Vector3

	raycastParams.FilterDescendantsInstances = filter
	if gunData then
		const sweep = Ballistics.Sweep(gunData, origin, unitDirection, range, raycastParams, rewound)
		if (sweep.Closest - rewound).Magnitude > (hitbox or HITBOX_RADIUS) then
			return false, nil, nil, nil
		end
		return true, target, claimedHitPart, sweep.Distance
	end

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

	for _, candidate in self:Candidates(shooter) do
		const rewindAt = if candidate.Character then timestamp else timestamp - BotSettings.InterpolationDelay
		const rewound = self.Dependencies.SnapshotService:GetRewoundPosition(candidate.ID, rewindAt)
			or candidate.Root
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

		raycastParams.FilterDescendantsInstances = if candidate.Character
			then { shooterCharacter, candidate.Character }
			else { shooterCharacter }
		if workspace:Raycast(origin, offset, raycastParams) then
			continue
		end

		table.insert(hits, { Target = candidate.Fighter, HitPart = Body.Torso, Distance = distance })
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

function HitService:ApplyHit(shooter: Fighter, hit: ResolvedHit, gunData: GetGun.GunData, gunName: string, origin: Vector3)
	const dealt, killed = self:DealDamage(shooter, hit.Target, self:HitDamage(gunData, hit), hit.HitPart == Body.Head)
	if not dealt then
		return
	end

	const victimRoot = rootPart(BotTypes.Character(hit.Target))
	if victimRoot then
		self:ApplyKnockback(victimRoot, victimRoot.Position - origin, gunData.Knockback)
	end

	const shooterPlayer = BotTypes.AsPlayer(shooter)
	const victimPlayer = BotTypes.AsPlayer(hit.Target)
	if gunData.FireMode == "Cone" and not killed and shooterPlayer and victimPlayer then
		self.Burned:Fire(shooterPlayer, victimPlayer, gunName)
	end

	if killed then
		const isHeadshot = hit.HitPart == Body.Head
		self.Dependencies.MatchStatsService:RecordKill(shooter, hit.Target, isHeadshot)
		self:Announce(shooter, hit.Target, gunName, isHeadshot)
	end
end

function HitService:ApplyHits(shooter: Fighter, hits: { ResolvedHit }, gunData: GetGun.GunData, gunName: string, origin: Vector3): number
	local landed = 0
	for _, hit in hits do
		if self.Dependencies.TeamService:SameTeam(shooter, hit.Target) or not self:IsAlive(hit.Target) then
			continue
		end
		landed += 1

		const travel = if gunData.FireMode == "Hitscan" then Ballistics.Travel(gunData, hit.Distance) else 0
		if travel > MIN_TRAVEL_DELAY then
			task.delay(travel, function()
				self:ApplyHit(shooter, hit, gunData, gunName, origin)
			end)
		else
			self:ApplyHit(shooter, hit, gunData, gunName, origin)
		end
	end
	return landed
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

	const landed = self:ApplyHits(shooter, hits, gunData, gunName, request.Origin)

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
