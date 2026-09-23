local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local Body = require(ReplicatedStorage.Shared.Templates.Body)

local MAX_HIT_RANGE = 150

local HITBOX_RADIUS = 4.5

local ORIGIN_TOLERANCE = 10

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local function closestPointOnRay(origin: Vector3, direction: Vector3, maxDistance: number, point: Vector3): Vector3
	local t = math.clamp((point - origin):Dot(direction), 0, maxDistance)
	return origin + direction * t
end

local HitService = Modux.Service("HitService"):Import("IDService"):Import("SnapshotService")
type Self = typeof(HitService)

HitService.DealDamage = function(self: Self, Target: Player, Shooter: Player, damage: number): boolean
	local targetVital = self:GetComponent(Target, "VitalComponent")
	if not targetVital then
		return false
	end
	local survived = targetVital:TakeDamage(damage)
	return not survived
end

HitService.ApplyKnockback = function(self: Self, root: BasePart, direction: Vector3, force: number)
	if direction.Magnitude < 0.001 or force <= 0 then
		return
	end
	root:ApplyImpulse(direction.Unit * force * root.AssemblyMass)
end

HitService.ResolvePellet = function(
	self: Self,
	Shooter: Player,
	origin: Vector3,
	direction: Vector3,
	claimedTargetID: number,
	claimedHitPart: number,
	timestamp: number
): (boolean, Player?, number?)
	if direction.Magnitude < 0.5 then
		return false, nil, nil
	end
	direction = direction.Unit

	local targetPlayer = self.IDService:GetPlayerFromID(claimedTargetID)
	if not targetPlayer or targetPlayer == Shooter then
		return false, nil, nil
	end

	local shooterCharacter = Shooter.Character
	local targetCharacter = targetPlayer.Character
	local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not shooterCharacter or not targetCharacter or not targetRoot then
		return false, nil, nil
	end

	local targetID = self.IDService:GetPlayerID(targetPlayer)
	local rewoundPosition = self.SnapshotService:GetRewoundPosition(targetID, timestamp) or targetRoot.Position

	raycastParams.FilterDescendantsInstances = { shooterCharacter, targetCharacter }
	local obstruction = workspace:Raycast(origin, direction * MAX_HIT_RANGE, raycastParams)
	local maxDistance = if obstruction then obstruction.Distance else MAX_HIT_RANGE

	local closestPoint = closestPointOnRay(origin, direction, maxDistance, rewoundPosition)
	if (closestPoint - rewoundPosition).Magnitude > HITBOX_RADIUS then
		return false, nil, nil
	end

	return true, targetPlayer, claimedHitPart
end

HitService.ProcessFire = function(self: Self, request, Shooter: Player): { Accepted: boolean, Hits: number }
	local reject = { Accepted = false, Hits = 0 }
	local shooterVital = self:GetComponent(Shooter, "VitalComponent")
	if not shooterVital or shooterVital.Health <= 0 then
		print(`[HitService] ProcessFire rejeitado -- {Shooter.Name} sem VitalComponent ou Health <= 0`)
		return reject
	end
	local shooterCharacter = Shooter.Character
	local shooterRoot = shooterCharacter and shooterCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not shooterCharacter or not shooterRoot then
		print(`[HitService] ProcessFire rejeitado -- {Shooter.Name} sem Character/HumanoidRootPart`)
		return reject
	end
	local claimedOrigin = Vector3.new(request.Origin.X, request.Origin.Y, request.Origin.Z)
	if (claimedOrigin - shooterRoot.Position).Magnitude > ORIGIN_TOLERANCE then
		print(
			`[HitService] ProcessFire rejeitado -- Origin alegada longe demais da real (dist={(
				claimedOrigin - shooterRoot.Position
			).Magnitude})`
		)
		return reject
	end
	local direction = request.Direction :: Vector3
	if direction.Magnitude < 0.5 then
		print(`[HitService] ProcessFire rejeitado -- Direction.Magnitude < 0.5 ({direction.Magnitude})`)
		return reject
	end
	direction = direction.Unit
	local Equipment = self:GetComponent(Shooter, "EquipmentComponent")
	if not Equipment or not Equipment.WeaponInstance or not Equipment.EquippedGunComponentID then
		print(
			`[HitService] ProcessFire rejeitado -- {Shooter.Name} sem EquipmentComponent/WeaponInstance/EquippedGunComponentID`
		)
		return reject
	end
	local gunComponent = self:GetComponent(Equipment.WeaponInstance, Equipment.EquippedGunComponentID)
	if not gunComponent then
		print(
			`[HitService] ProcessFire rejeitado -- componente "{Equipment.EquippedGunComponentID}" não encontrado em WeaponInstance`
		)
		return reject
	end
	if not gunComponent:CanShoot(Equipment) then
		print(
			`[HitService] ProcessFire rejeitado -- CanShoot=false (ammo={Equipment.SlotAmmo[Equipment.ActiveSlot]}, fireRate={gunComponent.FireRate})`
		)
		return reject
	end
	local confirmedHits: { { Player: Player, HitPart: number } } = gunComponent:Shoot(
		Shooter,
		Equipment,
		claimedOrigin,
		direction,
		request.Pellets,
		request.TimeStamp,
		request.IsAiming == true
	)
	for _, confirmedHit in confirmedHits do
		local targetPlayer = confirmedHit.Player
		local killed = self:DealDamage(targetPlayer, Shooter, gunComponent.Damage)
		local targetCharacter = targetPlayer.Character
		local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
		if targetRoot then
			self:ApplyKnockback(targetRoot, targetRoot.Position - claimedOrigin, gunComponent.Knockback)
		end
		if killed then
			self.Network.Packages.KillFeed:send({
				ShooterID = self.IDService:GetPlayerID(Shooter),
				VictimID = self.IDService:GetPlayerID(targetPlayer),
				GunName = gunComponent.GunName,
				IsHeadshot = confirmedHit.HitPart == Body.Head,
			}, self.Network.all)
		end
	end
	self:ApplyKnockback(shooterRoot, -direction, gunComponent.Knockback)
	return { Accepted = true, Hits = #confirmedHits }
end

HitService:OnInit(function(self)
	self.Network.Packages.Fire:handle(function(request, player: Player?): { Accepted: boolean, Hits: number }?
		if not player then
			return nil
		end
		return self:ProcessFire(request, player)
	end)
end)

HitService:OnStart(function(self) end)

return HitService
