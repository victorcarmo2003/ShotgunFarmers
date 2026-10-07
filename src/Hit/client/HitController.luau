--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Ballistics = require(ReplicatedStorage.shared.Weapon.Ballistics)
local Body = require(ReplicatedStorage.shared.Hit.Body)
local GameSettings = require(ReplicatedStorage.shared.Settings.GameSettings)
local GetBodyPart = require(ReplicatedStorage.shared.Hit.GetBodyPart)
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local HitNet = require(ReplicatedStorage.shared.Hit.Net)
local Throwables = require(ReplicatedStorage.shared.Weapon.Throwables)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WeaponSounds = require(ReplicatedStorage.shared.Weapon.WeaponSounds)
local WeaponVFX = require(ReplicatedStorage.shared.Weapon.WeaponVFX)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type FireRequest = {
	Origin: Vector3,
	Direction: Vector3,
	Pellets: { HitNet.Pellet },
	IsAiming: boolean,
	TimeStamp: number,
}

const MAX_CLAIMS = 12
const MELEE_RADIUS = 1.5
const BULLET_FOLDER = "Bullets"

const raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

const HitController = Modux.Controller("HitController", {
	Require = {
		"ArmsController",
		"GameStateController",
		"InputController",
		"MovementController",
		"ThrowableController",
		"VFXController",
		"WeaponController",
	},
	Priority = 450,
})

function HitController:Setup()
	self.LastShotTime = 0 :: number
	self.HitMarkerTrigger = Vide.source(0) :: Vide.Source<number>
	self.Holding = false :: boolean
	self.InFlight = 0 :: number
	self.Fired = self.Libs.Signal.new() :: SignalLib.Signal<GetGun.GunData>
end

local function playerFromPart(part: Instance): Player?
	const model = part:FindFirstAncestorOfClass("Model")
	if not model then
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

local function ignoreList(character: Model): { Instance }
	const ignore: { Instance } = { character }

	const camera = workspace.CurrentCamera
	if camera then
		table.insert(ignore, camera)
	end

	for _, name in { BULLET_FOLDER, Throwables.FOLDER_NAME } do
		const folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end

	return ignore
end

local function pelletFor(
	result: RaycastResult?,
	endPos: Vector3,
	direction: Vector3,
	claim: HitNet.Pellet?,
	delay: number?
): WeaponVFX.Pellet
	local kind: WeaponVFX.PelletKind = "Wall"
	if not result then
		kind = "None"
	elseif claim then
		kind = if claim.HitPart == Body.Head then "Head" else "Player"
	end

	const pellet: WeaponVFX.Pellet = {
		EndPos = endPos,
		Normal = if result then result.Normal else -direction,
		Kind = kind,
		Delay = delay,
	}
	return pellet
end

local function claimFor(result: RaycastResult): HitNet.Pellet?
	const target = playerFromPart(result.Instance)
	const targetID = if target then target:GetAttribute("GameID") else nil
	if typeof(targetID) ~= "number" then
		return nil
	end

	return { TargetID = targetID, HitPart = GetBodyPart.Get(result.Instance.Name) }
end

function HitController:PlayShotSound(gunData: GetGun.GunData)
	const soundName = WeaponSounds.ShootName(gunData.DisplayName)
	if soundName == "" then
		return
	end

	const camera = workspace.CurrentCamera
	if camera then
		WeaponSounds.PlayPooled(soundName, camera)
	else
		WeaponSounds.Play2D(soundName)
	end
end

function HitController:CanFire(): boolean
	return self.Dependencies.InputController.Context ~= "Menu" and self.Dependencies.GameStateController:Can("Combat")
end

function HitController:Send(request: FireRequest, hitPosition: Vector3?, consumes: boolean, travel: number)
	if consumes then
		self.InFlight += 1
	end

	const sentAt = os.clock()
	const ok, reply = self.Libs.Net.Hit.Fire:request(request)

	if consumes then
		self.InFlight = math.max(self.InFlight - 1, 0)
	end

	if not ok or reply.Hits <= 0 then
		return
	end

	const remaining = travel - (os.clock() - sentAt)
	if remaining > 0 then
		task.wait(remaining)
	end

	self.HitMarkerTrigger(self.HitMarkerTrigger() + 1)
	if hitPosition then
		WeaponSounds.PlayAt(WeaponSounds.RandomHit(), hitPosition)
	end
end

function HitController:Dispatch(request: FireRequest, hitPosition: Vector3?, consumes: boolean, travel: number?)
	task.spawn(function()
		self:Send(request, hitPosition, consumes, travel or 0)
	end)
end

function HitController:FireHitscan(gunData: GetGun.GunData, origin: Vector3, look: Vector3, now: number)
	const arms = self.Dependencies.ArmsController
	const isAiming = arms.IsAiming()
	const trailOrigin = arms:GetMuzzlePosition() or origin

	local spread = gunData.Spread
	if self.Dependencies.MovementController.IsMoving() then
		spread *= GameSettings.MovingSpreadMultiplier
	end
	if isAiming then
		spread *= GameSettings.AimSpreadMultiplier
	end

	arms:PlayShoot()
	self:PlayShotSound(gunData)

	const pellets: { HitNet.Pellet } = {}
	const visuals: { WeaponVFX.Pellet } = {}
	local hitPosition: Vector3? = nil
	local hitTravel = 0
	local wallPosition: Vector3? = nil
	local wallTravel = 0

	for _ = 1, gunData.Bullets do
		const direction = spreadDirection(look, spread)
		const cast = Ballistics.Cast(gunData, origin, direction, raycastParams)
		const result = cast.Result
		local claim: HitNet.Pellet? = nil

		if result then
			claim = claimFor(result)
			if claim then
				if #pellets < MAX_CLAIMS then
					table.insert(pellets, claim)
				end
				if not hitPosition then
					hitPosition = result.Position
					hitTravel = cast.Travel
				end
			elseif not wallPosition then
				wallPosition = result.Position
				wallTravel = cast.Travel
			end
		end

		table.insert(visuals, pelletFor(result, cast.EndPos, direction, claim, cast.Travel))
	end

	self.Dependencies.VFXController:LocalShot(gunData, look, trailOrigin, visuals)

	const wall = wallPosition
	if wall then
		task.delay(wallTravel, function()
			WeaponSounds.PlayAt(WeaponSounds.RandomWall(), wall)
		end)
	end

	self:Dispatch({
		Origin = origin,
		Direction = look,
		Pellets = pellets,
		IsAiming = isAiming,
		TimeStamp = now,
	}, hitPosition, true, hitTravel)
end

function HitController:FireMelee(gunData: GetGun.GunData)
	self.Dependencies.ArmsController:PlayAttack()

	const delay = gunData.HitDelay or 0
	if delay <= 0 then
		self:Strike(gunData)
		return
	end

	task.delay(delay, function()
		if self.Dependencies.WeaponController:GunData() == gunData and self:CanFire() then
			self:Strike(gunData)
		end
	end)
end

function HitController:Strike(gunData: GetGun.GunData)
	const character = self.Dependencies.MovementController.Character
	const primaryPart = if character then character.PrimaryPart else nil
	const look = cameraLook()
	if not character or not primaryPart or not look then
		return
	end

	raycastParams.FilterDescendantsInstances = ignoreList(character)
	const origin = primaryPart.Position
	const now = workspace:GetServerTimeNow()

	const pellets: { HitNet.Pellet } = {}
	local hitPosition: Vector3? = nil

	const result = workspace:Spherecast(origin, MELEE_RADIUS, look * gunData.Range, raycastParams)
	if result then
		const claim = claimFor(result)
		if claim then
			table.insert(pellets, claim)
			hitPosition = result.Position
		else
			WeaponSounds.PlayAt(WeaponSounds.RandomWall(), result.Position)
		end

		self.Dependencies.VFXController:LocalShot(gunData, look, result.Position, { pelletFor(result, result.Position, look, claim) })
	end

	self:Dispatch({
		Origin = origin,
		Direction = look,
		Pellets = pellets,
		IsAiming = false,
		TimeStamp = now,
	}, hitPosition, false)
end

function HitController:FireCone(gunData: GetGun.GunData, origin: Vector3, look: Vector3, now: number)
	const arms = self.Dependencies.ArmsController
	arms:PlayShoot()

	self.Dependencies.VFXController:LocalFlame(gunData, arms:GetMuzzlePosition() or origin, look)

	self:Dispatch({
		Origin = origin,
		Direction = look,
		Pellets = {},
		IsAiming = arms.IsAiming(),
		TimeStamp = now,
	}, nil, true)
end

function HitController:FireProjectile(gunData: GetGun.GunData, look: Vector3): boolean
	if not self.Dependencies.ThrowableController:Launch() then
		return false
	end

	self.Dependencies.ArmsController:PlayShoot()
	self:PlayShotSound(gunData)
	self.Dependencies.VFXController:LocalShot(gunData, look, Vector3.zero, {})
	return true
end

function HitController:TryHit(pressed: boolean): boolean
	const now = workspace:GetServerTimeNow()
	const weapon = self.Dependencies.WeaponController

	if now < weapon.DrawEndsAt() then
		return false
	end

	const gunData = weapon:GunData()
	if not gunData or gunData.Disabled then
		return false
	end

	if gunData.FireMode == "Throw" then
		return pressed and self.Dependencies.ThrowableController:Press("Left")
	end

	if now - self.LastShotTime < gunData.FireRate then
		return false
	end

	const consumes = GetGun.UsesAmmo(gunData)
	if consumes and weapon:ActiveAmmo() - self.InFlight <= 0 then
		return false
	end

	const character = self.Dependencies.MovementController.Character
	const primaryPart = if character then character.PrimaryPart else nil
	const look = cameraLook()
	if not character or not primaryPart or not look then
		return false
	end

	self.LastShotTime = now
	raycastParams.FilterDescendantsInstances = ignoreList(character)

	const origin = primaryPart.Position
	const mode = gunData.FireMode
	if mode ~= "Melee" then
		self.Fired:Fire(gunData)
	end

	if mode == "Projectile" then
		return self:FireProjectile(gunData, look)
	elseif mode == "Melee" then
		self:FireMelee(gunData)
	elseif mode == "Cone" then
		self:FireCone(gunData, origin, look, now)
	else
		self:FireHitscan(gunData, origin, look, now)
	end

	return true
end

function HitController:StepHold()
	if not self.Holding then
		return
	end

	if not self:CanFire() then
		self.Holding = false
		return
	end

	self:TryHit(false)
end

HitController:OnInit(function(self)
	self:Setup()
end)

HitController:OnStart(function(self)
	const fire = self.Dependencies.InputController:Bind({
		Name = "Fire",
		Key = Enum.UserInputType.MouseButton1,
		TouchButton = true,
		Priority = 10,
		Requires = "Combat",
	})

	fire.OnPress(function()
		self.Holding = true
		self:TryHit(true)
	end)

	fire.OnRelease(function()
		self.Holding = false
		self.Dependencies.ThrowableController:ReleaseButton("Left")
	end)

	RunService.Heartbeat:Connect(function()
		self:StepHold()
	end)
end)

return HitController
