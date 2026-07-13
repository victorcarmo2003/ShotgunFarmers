local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local Body = require(ReplicatedStorage.Shared.Templates.Body)

-- Mesmo alcance do raycast local em CameraController.MAX_RANGE (client) -- mantidos
-- separados de propósito: client e server não devem compartilhar constante de gameplay
-- por um require cross-realm.
local MAX_HIT_RANGE = 150
-- Raio de "hitbox" aproximado (esfera única por character, não o skeleton real).
local HITBOX_RADIUS = 4.5
-- Quão longe a Origin alegada pelo client pode estar da posição real do atirador.
local ORIGIN_TOLERANCE = 8

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

-- Ponto mais próximo de `point` no segmento [origin, origin + direction*maxDistance].
-- `direction` precisa estar normalizado.
local function closestPointOnRay(origin: Vector3, direction: Vector3, maxDistance: number, point: Vector3): Vector3
	local t = math.clamp((point - origin):Dot(direction), 0, maxDistance)
	return origin + direction * t
end

local HitService = Modux.Service("HitService"):Import("IDService"):Import("SnapshotService")

-- Retorna true se o alvo morreu com esse dano -- VitalComponent.TakeDamage devolve
-- false quando mata (ver VitalComponent.luau), aqui só espelhamos isso pro chamador
-- decidir se dispara o KillFeed.
HitService.DealDamage = function(self, Target: Player, Shooter: Player, damage: number): boolean
	local targetVital = self:GetComponent(Target, "VitalComponent")
	if not targetVital then
		return false
	end
	local survived = targetVital:TakeDamage(damage)
	return not survived
end

-- Empurra `root` na direção `direction` com força `force` (impulso, respeita a massa
-- do assembly). Usado tanto pro recuo do atirador quanto pro knockback de quem foi atingido.
HitService.ApplyKnockback = function(self, root: BasePart, direction: Vector3, force: number)
	if direction.Magnitude < 0.001 or force <= 0 then
		return
	end
	root:ApplyImpulse(direction.Unit * force * root.AssemblyMass)
end

-- Valida um único projétil: resolve o alvo reivindicado pelo client, rebobina a posição
-- dele (SnapshotService) e confirma se o raio passa perto o suficiente da hitbox.
-- Não aplica dano nem checa fire-rate -- isso é responsabilidade de quem chama.
HitService.ResolvePellet = function(
	self,
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

	-- HitPart não é revalidado contra a geometria real (a hitbox é uma esfera única por
	-- character, não o skeleton) -- só serve pra cosmética do KillFeed (ícone de headshot),
	-- mesma lógica de confiança do IsAiming: mentir aqui não muda dano nem confirma acerto.
	return true, targetPlayer, claimedHitPart
end

-- Orquestra um disparo completo: valida quem atirou, resolve a arma equipada,
-- checa o gate de fire-rate/munição dela, delega o(s) projétil(eis) pro componente
-- da arma (que sabe quantos e com que espalhamento) e aplica dano + knockback nos
-- acertos confirmados, além do recuo no atirador -- sempre, mesmo errando o tiro.
HitService.ProcessFire = function(self, request, Shooter: Player): { Accepted: boolean, Hits: number }
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
			`[HitService] ProcessFire rejeitado -- Origin alegada longe demais da real (dist={(claimedOrigin - shooterRoot.Position).Magnitude})`
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
		print(`[HitService] ProcessFire rejeitado -- {Shooter.Name} sem EquipmentComponent/WeaponInstance/EquippedGunComponentID`)
		return reject
	end

	local gunComponent = self:GetComponent(Equipment.WeaponInstance, Equipment.EquippedGunComponentID)
	if not gunComponent then
		print(`[HitService] ProcessFire rejeitado -- componente "{Equipment.EquippedGunComponentID}" não encontrado em WeaponInstance`)
		return reject
	end

	if not gunComponent:CanShoot(Equipment) then
		print(
			`[HitService] ProcessFire rejeitado -- CanShoot=false (ammo={Equipment.SlotAmmo[Equipment.ActiveSlot]}, fireRate={gunComponent.FireRate})`
		)
		return reject
	end

	print(`[HitService] ProcessFire aceito -- {Shooter.Name} atirou com "{gunComponent.GunName}"`)

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

	-- Recuo do atirador acontece sempre, mesmo errando -- é o que sustenta o shotgun-jump.
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
