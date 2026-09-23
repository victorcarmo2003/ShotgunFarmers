--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Body = require(ReplicatedStorage.shared.Hit.Body)
local HitNet = require(ReplicatedStorage.shared.Hit.Net)
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

const MAX_HIT_RANGE = 150
const HITBOX_RADIUS = 4.5
const ORIGIN_TOLERANCE = 10

const TIMESTAMP_AHEAD = 0.25
const TIMESTAMP_BEHIND = 1

const FIRES_PER_SECOND = 15
const FIRE_BURST = 10

const REJECTED: FireReply = { Accepted = false, Hits = 0 }

const raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

const HitService = Modux.Service("HitService", {
	Require = { "IDService", "NetService", "PlayerService", "SnapshotService" },
	Priority = 500,
})

function HitService:Setup()
	self.Budget = {} :: { [Player]: FireBudget }
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

function HitService:DealDamage(target: Player, damage: number): boolean
	const vital = self.Components.Vital:Get(target)
	if not vital then
		return false
	end

	return not vital:TakeDamage(damage)
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

function HitService:ResolvePellet(
	shooter: Player,
	origin: Vector3,
	direction: Vector3,
	claimedTargetID: number,
	claimedHitPart: number,
	timestamp: number
): (boolean, Player?, number?)
	if direction.Magnitude < 0.5 then
		return false, nil, nil
	end
	const unitDirection = direction.Unit

	const target = self.Dependencies.IDService:GetPlayerFromID(claimedTargetID)
	if not target or target == shooter then
		return false, nil, nil
	end

	const shooterCharacter = shooter.Character
	const targetCharacter = target.Character
	const targetRoot = rootPart(targetCharacter)
	if not shooterCharacter or not targetCharacter or not targetRoot then
		return false, nil, nil
	end

	const rewound = self.Dependencies.SnapshotService:GetRewoundPosition(claimedTargetID, timestamp)
		or targetRoot.Position

	raycastParams.FilterDescendantsInstances = { shooterCharacter, targetCharacter }
	const obstruction = workspace:Raycast(origin, unitDirection * MAX_HIT_RANGE, raycastParams)
	const maxDistance = if obstruction then obstruction.Distance else MAX_HIT_RANGE

	const closest = closestPointOnRay(origin, unitDirection, maxDistance, rewound)
	if (closest - rewound).Magnitude > HITBOX_RADIUS then
		return false, nil, nil
	end

	return true, target, claimedHitPart
end

function HitService:ProcessFire(request: FireRequest, shooter: Player): FireReply
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

	if not gun:CanShoot(shooter, equipment:ActiveAmmo()) then
		return REJECTED
	end

	if not equipment:ConsumeAmmo(1) then
		return REJECTED
	end

	const gunData = gun:Data()
	const hits = gun:Shoot(
		shooter,
		request.Origin,
		direction,
		request.Pellets,
		request.TimeStamp,
		request.IsAiming == true
	)

	for _, hit in hits do
		const killed = self:DealDamage(hit.Player, gunData.Damage)

		const victimRoot = rootPart(hit.Player.Character)
		if victimRoot then
			self:ApplyKnockback(victimRoot, victimRoot.Position - request.Origin, gunData.Knockback)
		end

		if killed then
			self:Announce(shooter, hit.Player, gunName, hit.HitPart == Body.Head)
		end
	end

	self:ApplyKnockback(root, -direction, gunData.Knockback)
	return { Accepted = true, Hits = #hits }
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
