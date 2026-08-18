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
type Self = typeof(HitController)

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

local function randomSpreadDirection(direction: Vector3, spread: number): Vector3
	if spread <= 0 then
		return direction
	end
	local randomAngleX = math.rad((math.random() - 0.5) * 2 * spread)
	local randomAngleY = math.rad((math.random() - 0.5) * 2 * spread)
	local baseCFrame = CFrame.lookAt(Vector3.zero, direction)
	return (baseCFrame * CFrame.Angles(randomAngleX, randomAngleY, 0)).LookVector
end

HitController.TryHit = function(self: Self): boolean
	local now = workspace:GetServerTimeNow()

	if now < self.WeaponController.DrawEndsAt then
		return false
	end

	local gunData = Fusion.peek(self.WeaponController.GunData)
	local poseKind = (gunData and gunData.PoseKind) or "Firearm"

	if poseKind == "Melee" then
		self.ArmsController:PlayAttack()
		return false
	elseif poseKind == "Throwable" then
		self.ArmsController:BeginThrow()
		return false
	end

	if self.ArmsController:GetPoseState() == "Reloading" then
		return false
	end

	local fireRate = (gunData and gunData.FireRate) or 0

	if now - self.LastShotTime < fireRate then
		return false
	end

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

	local originPosition = character.PrimaryPart.Position

	local visualOrigin = self.ArmsController:GetMuzzlePosition() or originPosition

	self.ArmsController:PlayShoot()

	local pelletCount = (gunData and gunData.Bullets) or 1
	local baseSpread = (gunData and gunData.Spread) or 0
	local isAiming = self.ArmsController.IsAiming == true
	local isMoving = self.LocalHumanoid.MoveDirection.Magnitude > 0.05

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

	if result and result.Hits and result.Hits > 0 then
		self.HitMarkerTrigger:set(Fusion.peek(self.HitMarkerTrigger) + 1)
	end

	return result ~= nil and result.Accepted
end

HitController:OnInit(function(self)
	self.Scope = Fusion.scoped(Fusion)

	self.HitMarkerTrigger = self.Scope:Value(0) :: Fusion.Value<number>
end)

HitController:OnStart(function(self)
	self.LastShotTime = 0 :: number

	local handler = self.InputController:BindAction("TryHit", Enum.UserInputType.MouseButton1)

	handler.OnPress(function()
		self:TryHit()
	end)

	handler.OnRelease(function()
		local gunData = Fusion.peek(self.WeaponController.GunData)
		if gunData and gunData.PoseKind == "Throwable" then
			self.ArmsController:ReleaseThrow()
		end
	end)
end)

return HitController
