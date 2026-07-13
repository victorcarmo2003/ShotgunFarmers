local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetBodyPart = require(ReplicatedStorage.Shared.Utils.GetBodyPart)
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local GameSettings = require(ReplicatedStorage.Shared.Settings.GameSettings)

local HitController = Modux.Controller("HitController")
	:Import("CameraController")
	:Import("InputController")
	:Import("WeaponController")
	:Import("ProjectileController")
	:Import("ArmsController")

local MAX_RANGE = 150

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local function toVector3int16(v: Vector3): Vector3int16
	return Vector3int16.new(math.round(v.X), math.round(v.Y), math.round(v.Z))
end

local function getPlayerFromPart(part: BasePart): Player?
	local model = part.Parent
	if not model or not model:IsA("Model") then
		return nil
	end
	return Players:GetPlayerFromCharacter(model)
end

-- Gera uma direção dentro de um cone ao redor de `direction`, aberto por `spread` graus.
-- Só serve pra detecção/visual local -- o server gera seu próprio espalhamento e
-- nunca confia nesta direção, só nos alvos que o client reivindica ter acertado.
local function randomSpreadDirection(direction: Vector3, spread: number): Vector3
	if spread <= 0 then
		return direction
	end
	local randomAngleX = math.rad((math.random() - 0.5) * 2 * spread)
	local randomAngleY = math.rad((math.random() - 0.5) * 2 * spread)
	local baseCFrame = CFrame.lookAt(Vector3.zero, direction)
	return (baseCFrame * CFrame.Angles(randomAngleX, randomAngleY, 0)).LookVector
end

-- Sempre dispara no clique, acerte ou não -- é isso que sustenta o recuo/knockback
-- do atirador mesmo errando o tiro (shotgun-jump). `Pellets` só carrega as
-- reivindicações de acerto que o client detectou localmente; o server valida cada uma.
HitController.TryHit = function(self): boolean
	local gunData = Fusion.peek(self.WeaponController.GunData)
	local fireRate = (gunData and gunData.FireRate) or 0
	local now = workspace:GetServerTimeNow()
	-- Gate de fire-rate no CLIENT -- sem isso, clicar mais rápido que o cooldown real
	-- ainda tocava a animação de tiro e spawnava os projéteis visuais a cada clique,
	-- mesmo que o server (GunMixin.CanShoot) fosse rejeitar a maioria das requests
	-- fora do cooldown -- a arma "parecia" atirar mais rápido do que realmente atira.
	if now - self.LastShotTime < fireRate then
		return false
	end

	-- Gate de munição no CLIENT -- sem isso, ficar sem bala ainda tocava a animação de
	-- tiro e spawnava os projéteis visuais a cada clique (o server rejeita via
	-- GunMixin.CanShoot, sem dano/som/consumo, mas os efeitos visuais já tinham
	-- disparado antes da resposta chegar) -- a arma "atirava pra sempre" sem munição.
	local ammo = Fusion.peek(self.WeaponController.Ammo)
	if ammo <= 0 then
		return false
	end

	local character = self.LocalCharacter
	local lookDirection = self.CameraController:GetLookDirection()
	if not character or not character.PrimaryPart or not lookDirection then
		return false
	end

	self.LastShotTime = now

	-- Origem de VALIDAÇÃO (server): sempre baseada no character, como já era.
	local originPosition = character.PrimaryPart.Position
	-- Origem VISUAL (client, cosmética): do Muzzle do viewmodel, se existir, senão
	-- cai pro character -- só afeta de onde a trilha do ProjectileController parte.
	local visualOrigin = self.ArmsController:GetMuzzlePosition() or originPosition

	self.ArmsController:PlayShoot()

	local pelletCount = (gunData and gunData.Bullets) or 1
	local baseSpread = (gunData and gunData.Spread) or 0
	local isAiming = self.ArmsController.IsAiming == true
	local isMoving = self.LocalHumanoid.MoveDirection.Magnitude > 0.05
	-- Mesma combinação do server (GunMixin.GetEffectiveSpread) -- só cosmético/
	-- reivindicação local aqui, mas precisa bater com o real pra não sugerir
	-- visualmente um cone diferente do que o server vai validar.
	local spread = baseSpread
	if isMoving then
		spread *= GameSettings.MovingSpreadMultiplier
	end
	if isAiming then
		spread *= GameSettings.AimSpreadMultiplier
	end
	local ammoType = (gunData and gunData.BulletType) or "Single"

	raycastParams.FilterDescendantsInstances = { character }

	local pellets = {}
	for _ = 1, pelletCount do
		local pelletDirection = randomSpreadDirection(lookDirection, spread)
		local rayResult = workspace:Raycast(originPosition, pelletDirection * MAX_RANGE, raycastParams)
		local endPosition = originPosition + pelletDirection * MAX_RANGE

		if rayResult then
			endPosition = rayResult.Position
			local hitPlayer = getPlayerFromPart(rayResult.Instance)
			local targetID = hitPlayer and hitPlayer:GetAttribute("GameID")
			if targetID then
				table.insert(pellets, {
					TargetID = targetID,
					HitPart = GetBodyPart.Get(rayResult.Instance.Name),
				})
			end
		end

		self.ProjectileController:Shoot({
			startPos = visualOrigin,
			endPos = endPosition,
			ammoType = ammoType,
		})
	end

	local result = self.Network.Packages.Fire:request({
		Origin = toVector3int16(originPosition),
		Direction = lookDirection,
		Pellets = pellets,
		IsAiming = isAiming,
		TimeStamp = workspace:GetServerTimeNow(),
	})

	-- Só o server confirma quantos pellets realmente acertaram (HitService.ProcessFire) --
	-- o marcador de hit reage a isso, nunca às reivindicações locais em `pellets`.
	if result and result.Hits and result.Hits > 0 then
		self.HitMarkerTrigger:set(Fusion.peek(self.HitMarkerTrigger) + 1)
	end

	return result ~= nil and result.Accepted
end

HitController:OnInit(function(self)
	self.Scope = Fusion.scoped(Fusion)
	-- Contador que só sobe -- InterfaceController observa as mudanças (não o valor em si)
	-- pra disparar o flash do HitMarker a cada acerto confirmado.
	self.HitMarkerTrigger = self.Scope:Value(0) :: Fusion.Value<number>
end)

HitController:OnStart(function(self)
	self.LastShotTime = 0 :: number

	local handler = self.InputController:BindAction("TryHit", Enum.UserInputType.MouseButton1)

	handler.OnPress(function()
		self:TryHit()
	end)
end)

return HitController
