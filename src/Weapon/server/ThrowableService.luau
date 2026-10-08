--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Body = require(ReplicatedStorage.shared.Hit.Body)
local GetBodyPart = require(ReplicatedStorage.shared.Hit.GetBodyPart)
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local ThrowSim = require(ReplicatedStorage.shared.Weapon.ThrowSim)
local Throwables = require(ReplicatedStorage.shared.Weapon.Throwables)
local WeaponVFX = require(ReplicatedStorage.shared.Weapon.WeaponVFX)
local GunRules = require(ServerScriptService.server.Weapon.GunRules)
local Modux = require(ServerScriptService.server.Modux)

export type ThrowRequest = {
	Origin: Vector3,
	Direction: Vector3,
	Target: Vector3,
	Mode: number,
	TimeStamp: number,
}

export type Projectile = {
	Id: number,
	Owner: Player,
	GunName: string,
	Definition: Throwables.Definition,
	State: ThrowSim.State,
	Params: RaycastParams,
	Plants: boolean,
}

export type Zone = {
	Owner: Player,
	GunName: string,
	Definition: Throwables.Definition,
	Spec: Throwables.ZoneSpec,
	Center: Vector3,
	EndsAt: number,
	NextDamage: number,
}

export type Burn = {
	Owner: Player,
	GunName: string,
	Dps: number,
	EndsAt: number,
	NextDamage: number,
}

const ORIGIN_TOLERANCE = 10
const TIMESTAMP_AHEAD = 0.25
const TIMESTAMP_BEHIND = 1
const MAX_CATCHUP_STEPS = 12
const MAX_ID = 65535
const ORIGIN_SURFACE_OFFSET = 0.6
const SHRAPNEL_LIFT = 0.15
const SLOW_KEY = "Acid"
const BURN_SOURCE = "Moolotov"

const ThrowableService = Modux.Service("ThrowableService", {
	Require = {
		"GameStateService",
		"HitService",
		"IDService",
		"MatchStatsService",
		"NetService",
		"PlayerService",
		"TeamService",
	},
	Priority = 450,
})

function ThrowableService:Setup()
	self.Projectiles = {} :: { [number]: Projectile }
	self.Zones = {} :: { Zone }
	self.Burns = {} :: { [Player]: Burn }
	self.Burning = {} :: { [Player]: boolean }
	self.Slowed = {} :: { [Player]: boolean }
	self.NextId = 0 :: number
	self.Accumulator = 0 :: number
	self.ScanAccumulator = 0 :: number
	self.SightParams = ThrowSim.Params() :: RaycastParams
end

local function rootPart(character: Model?): BasePart?
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function headPart(character: Model?): BasePart?
	const head = if character then character:FindFirstChild("Head") else nil
	return if head and head:IsA("BasePart") then head else nil
end

function ThrowableService:AllocateId(): number
	self.NextId = (self.NextId % MAX_ID) + 1
	return self.NextId
end

function ThrowableService:IsAlive(player: Player): boolean
	const vital = self.Components.Vital:Get(player)
	return vital ~= nil and vital.Alive
end

function ThrowableService:Hurt(owner: Player, victim: Player, amount: number, gunName: string, isHeadshot: boolean?)
	const ownerPresent = owner:IsDescendantOf(Players)
	local damage = amount
	if victim == owner then
		damage *= Throwables.SELF_DAMAGE_SCALE
	elseif ownerPresent and self.Dependencies.TeamService:SameTeam(owner, victim) then
		return
	end

	damage = math.round(damage)
	if damage <= 0 then
		return
	end

	const _, killed = self.Dependencies.HitService:DealDamage(owner, victim, damage)
	if killed and victim ~= owner and ownerPresent then
		self.Dependencies.MatchStatsService:RecordKill(owner, victim, isHeadshot == true)
		self.Dependencies.HitService:Announce(owner, victim, gunName, isHeadshot == true)
	end
end

function ThrowableService:SafeOrigin(character: Model, requested: Vector3): Vector3
	const head = headPart(character) or rootPart(character)
	if not head then
		return requested
	end

	const offset = requested - head.Position
	if offset.Magnitude < 0.01 then
		return requested
	end

	const params = self.SightParams
	params.FilterDescendantsInstances = ThrowSim.Ignore(nil, false)
	const blocked = workspace:Raycast(head.Position, offset, params)
	if not blocked then
		return requested
	end

	return blocked.Position + blocked.Normal * ORIGIN_SURFACE_OFFSET
end

function ThrowableService:ProcessThrow(request: ThrowRequest, player: Player)
	if not self.Dependencies.GameStateService:Can("Combat") then
		return
	end

	const now = workspace:GetServerTimeNow()
	const drift = now - request.TimeStamp
	if drift < -TIMESTAMP_AHEAD or drift > TIMESTAMP_BEHIND then
		return
	end

	if not self:IsAlive(player) then
		return
	end

	const character = player.Character
	const root = rootPart(character)
	if not character or not root then
		return
	end

	if (request.Origin - root.Position).Magnitude > ORIGIN_TOLERANCE then
		return
	end

	if request.Direction.Magnitude < 0.5 then
		return
	end

	const equipment = self.Components.Equipment:Get(player)
	if not equipment then
		return
	end

	const weaponInstance, gunName = equipment:ActiveGun()
	if not weaponInstance or not gunName then
		return
	end

	const gunData = GetGun.ByName(gunName)
	const definition = Throwables.Get(gunName)
	if not gunData or not definition then
		return
	end

	const launcher = gunData.FireMode == "Projectile"
	if gunData.FireMode ~= "Throw" and not launcher then
		return
	end

	const gun = self.Components.Gun:Get(weaponInstance)
	if not gun or not gun:CanShoot(player, equipment:ActiveAmmo(), request.TimeStamp) then
		return
	end

	if not equipment:ConsumeAmmo(1) then
		return
	end
	gun:MarkShot(request.TimeStamp)

	const origin = self:SafeOrigin(character, request.Origin)
	const power = ThrowSim.Power(launcher, request.Mode)
	const velocity, curve = ThrowSim.Aim(definition, origin, request.Direction, request.Target, power)
	self:Launch(player, gunName, gunData.ID, definition, origin, velocity, curve, math.min(drift, TIMESTAMP_BEHIND))

	if launcher then
		gun:PlaySound(player)
		self.Dependencies.HitService:ApplyKnockback(root, -request.Direction.Unit, gunData.Knockback)
	end
end

function ThrowableService:Launch(
	owner: Player,
	gunName: string,
	kind: number,
	definition: Throwables.Definition,
	origin: Vector3,
	velocity: Vector3,
	curve: number,
	latency: number
)
	const id = self:AllocateId()
	const gunData = GetGun.ByName(gunName)
	const projectile: Projectile = {
		Id = id,
		Owner = owner,
		GunName = gunName,
		Definition = definition,
		State = ThrowSim.new(origin, velocity, curve),
		Params = ThrowSim.Params(),
		Plants = gunData ~= nil and gunData.FireMode == "Projectile" and GunRules.RollSeed(gunName),
	}
	self.Projectiles[id] = projectile

	const catchup = math.clamp(math.floor(math.max(latency, 0) / Throwables.STEP), 0, MAX_CATCHUP_STEPS)
	const serverTime = workspace:GetServerTimeNow() - catchup * Throwables.STEP
	if self.Dependencies.NetService:IsRunning() then
		self.Libs.Net.Weapon.ThrowSpawn:fireClient(self.Dependencies.NetService.Audience, {
			Id = id,
			Kind = kind,
			OwnerID = if owner:IsDescendantOf(Players) then self.Dependencies.IDService:GetPlayerID(owner) else 0,
			Origin = origin,
			Velocity = velocity,
			Curve = curve,
			ServerTime = serverTime,
		})
	end

	for _ = 1, catchup do
		if self:StepProjectile(projectile) then
			return
		end
	end
end

function ThrowableService:StepProjectile(projectile: Projectile): boolean
	const definition = projectile.Definition
	const state = projectile.State
	projectile.Params.FilterDescendantsInstances = ThrowSim.Ignore(projectile.Owner, definition.Contact)

	const contact = ThrowSim.Step(definition, state, projectile.Params)
	if contact then
		if definition.Direct then
			self:Strike(projectile, contact.Instance)
		end
		if projectile.Plants and GunRules.IsPlantable(contact.Instance) then
			GunRules.PlantAt(contact.Position, projectile.GunName)
		end
		self:Detonate(projectile, contact.Position + contact.Normal * Throwables.PROJECTILE_RADIUS)
		return true
	end

	if
		state.Age >= definition.Fuse
		or state.Position.Y < workspace.FallenPartsDestroyHeight
		or self:NearEnemy(projectile)
	then
		self:Detonate(projectile, state.Position)
		return true
	end

	return false
end

function ThrowableService:NearEnemy(projectile: Projectile): boolean
	const proximity = projectile.Definition.Proximity
	if not proximity then
		return false
	end

	const owner = projectile.Owner
	const ownerPresent = owner:IsDescendantOf(Players)
	const position = projectile.State.Position
	for _, player in Players:GetPlayers() do
		if player == owner or not self:IsAlive(player) then
			continue
		end

		if ownerPresent and self.Dependencies.TeamService:SameTeam(owner, player) then
			continue
		end

		const root = rootPart(player.Character)
		if root and (root.Position - position).Magnitude <= proximity then
			return true
		end
	end

	return false
end

function ThrowableService:Strike(projectile: Projectile, instance: Instance)
	const model = instance:FindFirstAncestorOfClass("Model")
	const victim = if model then Players:GetPlayerFromCharacter(model) else nil
	if not victim or victim == projectile.Owner or not self:IsAlive(victim) then
		return
	end

	const isHeadshot = GetBodyPart.Get(instance.Name) == Body.Head
	const gunData = GetGun.ByName(projectile.GunName)
	local damage = projectile.Definition.DamageCenter
	if isHeadshot and gunData then
		damage *= gunData.HeadshotMultiplier
	end

	self:Hurt(projectile.Owner, victim, damage, projectile.GunName, isHeadshot)
end

function ThrowableService:CanSee(center: Vector3, character: Model): boolean
	const params = self.SightParams
	params.FilterDescendantsInstances = ThrowSim.Ignore(nil, false)

	for _, part in { rootPart(character), headPart(character) } do
		if part and not workspace:Raycast(center, part.Position - center, params) then
			return true
		end
	end

	return false
end

function ThrowableService:Blast(projectile: Projectile, center: Vector3)
	const definition = projectile.Definition
	for _, player in Players:GetPlayers() do
		const character = player.Character
		const root = rootPart(character)
		if not character or not root or not self:IsAlive(player) then
			continue
		end

		const distance = (root.Position - center).Magnitude
		if distance > definition.Radius then
			continue
		end

		if not self:CanSee(center, character) then
			continue
		end

		self:Hurt(projectile.Owner, player, Throwables.Falloff(definition, distance), projectile.GunName)
	end
end

function ThrowableService:Shrapnel(projectile: Projectile, center: Vector3): { Vector3 }
	const spec = projectile.Definition.Shrapnel
	const ends: { Vector3 } = {}
	if not spec then
		return ends
	end

	const params = ThrowSim.Params()
	params.FilterDescendantsInstances = ThrowSim.Ignore(nil, true)

	const baseAngle = math.random() * math.pi * 2
	for index = 1, spec.Count do
		const angle = baseAngle + (index - 1) * (math.pi * 2 / spec.Count)
		const direction = Vector3.new(math.cos(angle), SHRAPNEL_LIFT, math.sin(angle)).Unit
		const result = workspace:Raycast(center, direction * spec.Range, params)
		table.insert(ends, if result then result.Position else center + direction * spec.Range)

		const model = if result then result.Instance:FindFirstAncestorOfClass("Model") else nil
		const victim = if model then Players:GetPlayerFromCharacter(model) else nil
		if victim and self:IsAlive(victim) then
			self:Hurt(projectile.Owner, victim, spec.Damage, projectile.GunName)
		end
	end

	return ends
end

function ThrowableService:GroundBelow(position: Vector3): Vector3
	const params = self.SightParams
	params.FilterDescendantsInstances = ThrowSim.Ignore(nil, false)
	const result = workspace:Raycast(position, Vector3.yAxis * -Throwables.ZONE_GROUND_PROBE, params)
	return if result then result.Position else position
end

function ThrowableService:Detonate(projectile: Projectile, position: Vector3)
	self.Projectiles[projectile.Id] = nil

	const definition = projectile.Definition
	self:Blast(projectile, position)
	const shards = self:Shrapnel(projectile, position)

	local zoneCenter = position
	const spec = definition.Zone
	if spec then
		zoneCenter = self:GroundBelow(position)
		const now = workspace:GetServerTimeNow()
		table.insert(self.Zones, {
			Owner = projectile.Owner,
			GunName = projectile.GunName,
			Definition = definition,
			Spec = spec,
			Center = zoneCenter,
			EndsAt = now + spec.Duration,
			NextDamage = now + Throwables.ZONE_DAMAGE_INTERVAL,
		})
	end

	if self.Dependencies.NetService:IsRunning() then
		self.Libs.Net.Weapon.ThrowDetonate:fireClient(self.Dependencies.NetService.Audience, {
			Id = projectile.Id,
			Position = position,
			ZoneCenter = zoneCenter,
			Shards = shards,
		})
	end
end

function ThrowableService:Ignite(owner: Player, victim: Player, gunName: string)
	const source = Throwables.Get(BURN_SOURCE)
	const spec = if source then source.Zone else nil
	if not spec or spec.LingerDps <= 0 or not self:IsAlive(victim) then
		return
	end

	const now = workspace:GetServerTimeNow()
	const existing = self.Burns[victim]
	self.Burns[victim] = {
		Owner = owner,
		GunName = gunName,
		Dps = spec.LingerDps,
		EndsAt = now + spec.LingerSeconds,
		NextDamage = if existing then existing.NextDamage else now + Throwables.ZONE_DAMAGE_INTERVAL,
	}
	self:SyncBurning()
end

function ThrowableService:SyncBurning()
	for player in self.Burning do
		if not self.Burns[player] then
			self.Burning[player] = nil
			player:SetAttribute(WeaponVFX.BURNING_ATTRIBUTE, nil)
		end
	end

	for player in self.Burns do
		if not self.Burning[player] then
			self.Burning[player] = true
			player:SetAttribute(WeaponVFX.BURNING_ATTRIBUTE, true)
		end
	end
end

function ThrowableService:SetSlowed(player: Player, multiplier: number?)
	const movement = self.Components.Movement:Get(player)
	if movement then
		movement:SetSpeedModifier(SLOW_KEY, multiplier)
	end

	self.Slowed[player] = if multiplier then true else nil
end

function ThrowableService:ScanZones(now: number)
	const slowed: { [Player]: number } = {}
	const inFire: { [Player]: boolean } = {}

	for index = #self.Zones, 1, -1 do
		const zone = self.Zones[index]
		if now >= zone.EndsAt then
			table.remove(self.Zones, index)
			continue
		end

		const damageTick = now >= zone.NextDamage
		if damageTick then
			zone.NextDamage += Throwables.ZONE_DAMAGE_INTERVAL
		end

		const spec = zone.Spec
		for _, player in Players:GetPlayers() do
			const root = rootPart(player.Character)
			if not root or not self:IsAlive(player) then
				continue
			end

			if not Throwables.InsideZone(spec, zone.Center, root.Position) then
				continue
			end

			if spec.SpeedMultiplier < 1 then
				slowed[player] = math.min(slowed[player] or 1, spec.SpeedMultiplier)
			end

			if spec.LingerDps > 0 then
				inFire[player] = true
				self.Burns[player] = {
					Owner = zone.Owner,
					GunName = zone.GunName,
					Dps = spec.LingerDps,
					EndsAt = now + spec.LingerSeconds,
					NextDamage = now + Throwables.ZONE_DAMAGE_INTERVAL,
				}
			end

			if damageTick then
				self:Hurt(zone.Owner, player, spec.Dps * Throwables.ZONE_DAMAGE_INTERVAL, zone.GunName)
			end
		end
	end

	for player, burn in self.Burns do
		if now >= burn.EndsAt or not self:IsAlive(player) then
			self.Burns[player] = nil
		elseif not inFire[player] and now >= burn.NextDamage then
			burn.NextDamage += Throwables.ZONE_DAMAGE_INTERVAL
			self:Hurt(burn.Owner, player, burn.Dps * Throwables.ZONE_DAMAGE_INTERVAL, burn.GunName)
		end
	end

	for player in self.Slowed do
		if not slowed[player] then
			self:SetSlowed(player, nil)
		end
	end
	for player, multiplier in slowed do
		self:SetSlowed(player, multiplier)
	end

	self:SyncBurning()
end

function ThrowableService:Step(deltaTime: number)
	if next(self.Projectiles) ~= nil then
		self.Accumulator += deltaTime
		while self.Accumulator >= Throwables.STEP do
			self.Accumulator -= Throwables.STEP
			for _, projectile in self.Projectiles do
				self:StepProjectile(projectile)
			end
		end
	else
		self.Accumulator = 0
	end

	self.ScanAccumulator += deltaTime
	if self.ScanAccumulator < Throwables.ZONE_SCAN_INTERVAL then
		return
	end
	self.ScanAccumulator = 0

	if #self.Zones > 0 or next(self.Burns) ~= nil or next(self.Slowed) ~= nil then
		self:ScanZones(workspace:GetServerTimeNow())
	end
end

function ThrowableService:ClearAll()
	table.clear(self.Projectiles)
	table.clear(self.Zones)
	table.clear(self.Burns)
	self:SyncBurning()

	for player in self.Slowed do
		self:SetSlowed(player, nil)
	end

	if self.Dependencies.NetService:IsRunning() then
		self.Libs.Net.Weapon.ThrowClear:fireClient(self.Dependencies.NetService.Audience)
	end
end

function ThrowableService:ForgetPlayer(player: Player)
	self.Burns[player] = nil
	self.Slowed[player] = nil
	self:SyncBurning()
end

function ThrowableService:Connect()
	self.Libs.Net.Weapon.Throw:onServer(function(request, player)
		self:ProcessThrow(request, player)
	end)

	self.Dependencies.HitService.Burned:Connect(function(owner, victim, gunName)
		self:Ignite(owner, victim, gunName)
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self:ForgetPlayer(player)
	end)

	self.Dependencies.PlayerService.CharacterAdded:Connect(function(player)
		self:ForgetPlayer(player)
	end)

	self.Dependencies.GameStateService:OnChanged(function()
		if not self.Dependencies.GameStateService:Can("Combat") then
			self:ClearAll()
		end
	end)
end

const lifecycle = ThrowableService :: any

lifecycle:OnInit(function(self)
	self:Setup()
	self:Connect()
end)

lifecycle:OnStart(function(self)
	RunService.Heartbeat:Connect(function(deltaTime: number)
		self:Step(deltaTime)
	end)
end)

return ThrowableService
