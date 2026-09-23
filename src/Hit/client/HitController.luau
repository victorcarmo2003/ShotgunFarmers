--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local GameSettings = require(ReplicatedStorage.shared.Settings.GameSettings)
local GetBodyPart = require(ReplicatedStorage.shared.Hit.GetBodyPart)
local HitNet = require(ReplicatedStorage.shared.Hit.Net)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const MAX_RANGE = 150

const MAX_CLAIMS = 12

const raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

const HitController = Modux.Controller("HitController", {
	Require = {
		"ArmsController",
		"InputController",
		"MovementController",
		"ProjectileController",
		"WeaponController",
	},
	Priority = 450,
})

function HitController:Setup()
	self.LastShotTime = 0 :: number
	self.HitMarkerTrigger = Vide.source(0) :: Vide.Source<number>
end

local function playerFromPart(part: Instance): Player?
	const model = part.Parent
	if not model or not model:IsA("Model") then
		return nil
	end

	return Players:GetPlayerFromCharacter(model)
end

local function spreadDirection(direction: Vector3, spread: number): Vector3
	if spread <= 0 then
		return direction
	end

	const angleX = math.rad((math.random() - 0.5) * 2 * spread)
	const angleY = math.rad((math.random() - 0.5) * 2 * spread)
	return (CFrame.lookAt(Vector3.zero, direction) * CFrame.Angles(angleX, angleY, 0)).LookVector
end

local function cameraLook(): Vector3?
	const camera = workspace.CurrentCamera
	return if camera then camera.CFrame.LookVector else nil
end

function HitController:TryHit(): boolean
	const now = workspace:GetServerTimeNow()
	const weapon = self.Dependencies.WeaponController

	if now < weapon.DrawEndsAt() then
		return false
	end

	const gunData = weapon:GunData()
	if not gunData then
		return false
	end

	const arms = self.Dependencies.ArmsController

	if gunData.PoseKind == "Melee" then
		arms:PlayAttack()
		return true
	elseif gunData.PoseKind == "Throwable" then
		arms:BeginThrow()
		return true
	elseif gunData.PoseKind ~= "Firearm" then
		return false
	end

	if now - self.LastShotTime < gunData.FireRate then
		return false
	end

	if weapon:ActiveAmmo() <= 0 then
		return false
	end

	const movement = self.Dependencies.MovementController
	const character = movement.Character
	const primaryPart = if character then character.PrimaryPart else nil
	const lookDirection = cameraLook()
	if not character or not primaryPart or not lookDirection then
		return false
	end

	self.LastShotTime = now

	const origin = primaryPart.Position
	const isAiming = arms.IsAiming()

	const trailOrigin = arms:GetMuzzlePosition() or origin

	local spread = gunData.Spread
	if movement.IsMoving() then
		spread *= GameSettings.MovingSpreadMultiplier
	end
	if isAiming then
		spread *= GameSettings.AimSpreadMultiplier
	end

	raycastParams.FilterDescendantsInstances = { character }
	arms:PlayShoot()

	const pellets: { HitNet.Pellet } = {}
	for _ = 1, gunData.Bullets do
		const direction = spreadDirection(lookDirection, spread)
		const result = workspace:Raycast(origin, direction * MAX_RANGE, raycastParams)
		local endPos = origin + direction * MAX_RANGE

		if result then
			endPos = result.Position

			const target = playerFromPart(result.Instance)
			const targetID = if target then target:GetAttribute("GameID") else nil
			if typeof(targetID) == "number" and #pellets < MAX_CLAIMS then
				table.insert(pellets, {
					TargetID = targetID,
					HitPart = GetBodyPart.Get(result.Instance.Name),
				})
			end
		end

		self.Dependencies.ProjectileController:Shoot(trailOrigin, endPos)
	end

	const ok, reply = self.Libs.Net.Hit.Fire:request({
		Origin = origin,
		Direction = lookDirection,
		Pellets = pellets,
		IsAiming = isAiming,
		TimeStamp = now,
	})

	if not ok then
		warn(`[HitController] tiro sem resposta do servidor: {tostring(reply)}`)
		return false
	end

	if reply.Hits > 0 then
		self.HitMarkerTrigger(self.HitMarkerTrigger() + 1)
	end

	return reply.Accepted == true
end

HitController:OnInit(function(self)
	self:Setup()
end)

HitController:OnStart(function(self)
	const fire = self.Dependencies.InputController
		:Bind({ Name = "Fire", Key = Enum.UserInputType.MouseButton1, TouchButton = true, Priority = 10 })

	fire.OnPress(function()
		self:TryHit()
	end)

	fire.OnRelease(function()
		self.Dependencies.ArmsController:ReleaseThrow()
	end)
end)

return HitController
