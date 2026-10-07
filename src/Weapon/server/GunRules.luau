--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameSettings = require(ReplicatedStorage.shared.Settings.GameSettings)
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)

const PLANTABLE_TAG = "Farmland"
const PLANT_RAY_RANGE = 150

const FIRE_RATE_TOLERANCE = 0.85

const SEED_TAG = "Seed"

const MOVING_EPSILON = 0.05

const MIN_DIRECTION = 0.5

const plantParams = RaycastParams.new()
plantParams.FilterType = Enum.RaycastFilterType.Exclude

const GunRules = {}

function GunRules.DrawTime(gunData: GetGun.GunData?): number
	return (gunData and gunData.DrawTime) or GameSettings.WeaponDrawLock
end

function GunRules.EffectiveSpread(shooter: Player, baseSpread: number, isAiming: boolean): number
	local spread = baseSpread

	const character = shooter.Character
	const humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.MoveDirection.Magnitude > MOVING_EPSILON then
		spread *= GameSettings.MovingSpreadMultiplier
	end

	if isAiming then
		spread *= GameSettings.AimSpreadMultiplier
	end

	return spread
end

function GunRules.RandomSpread(direction: Vector3, spread: number): Vector3
	if spread <= 0 or direction.Magnitude < MIN_DIRECTION then
		return direction
	end

	const angleX = math.rad((math.random() - 0.5) * 2 * spread)
	const angleY = math.rad((math.random() - 0.5) * 2 * spread)
	return (CFrame.lookAt(Vector3.zero, direction) * CFrame.Angles(angleX, angleY, 0)).LookVector
end

function GunRules.CanShoot(
	gunData: GetGun.GunData,
	ammo: number,
	lastShoot: number,
	drawEndsAt: number,
	now: number,
	stamp: number
): (boolean, string?)
	if gunData.Disabled then
		return false, "Disabled"
	end

	if GetGun.UsesAmmo(gunData) and ammo <= 0 then
		return false, "NoAmmo"
	end

	if stamp - lastShoot < gunData.FireRate * FIRE_RATE_TOLERANCE then
		return false, "FireRate"
	end

	if now < drawEndsAt then
		return false, "Drawing"
	end

	return true, nil
end

local function seedsFolder(): Folder
	const existing = workspace:FindFirstChild("Seeds")
	if existing and existing:IsA("Folder") then
		return existing
	end

	const folder = Instance.new("Folder")
	folder.Name = "Seeds"
	folder.Parent = workspace
	return folder
end

local function dirtTemplate(): BasePart?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const seeds = assets and assets:FindFirstChild("Seeds")
	const dirt = seeds and seeds:FindFirstChild("Dirt")
	if dirt and dirt:IsA("BasePart") then
		return dirt
	end

	return nil
end

function GunRules.PlantAt(position: Vector3, gunName: string): BasePart?
	const template = dirtTemplate()
	if not template then
		warn("[GunRules] Assets.Seeds.Dirt nao encontrado; nada plantado")
		return nil
	end

	const dirt = template:Clone() :: BasePart
	dirt:PivotTo(CFrame.new(position) * dirt.CFrame.Rotation)
	dirt:SetAttribute("GunName", gunName)
	dirt:SetAttribute("PlantedAt", workspace:GetServerTimeNow())
	dirt.Parent = seedsFolder()
	CollectionService:AddTag(dirt, SEED_TAG)
	return dirt
end

function GunRules.RollSeed(gunName: string): boolean
	const gunData = GetGun.ByName(gunName)
	const chance = if gunData then gunData.SeedChance or 0 else 0
	return math.random() < chance
end

function GunRules.IsPlantable(instance: Instance): boolean
	return CollectionService:HasTag(instance, PLANTABLE_TAG)
end

function GunRules.TryPlant(shooter: Player, origin: Vector3, direction: Vector3, gunName: string, range: number?)
	if direction.Magnitude < MIN_DIRECTION then
		return
	end

	const filter: { Instance } = {}
	const character = shooter.Character
	if character then
		table.insert(filter, character)
	end
	plantParams.FilterDescendantsInstances = filter

	const distance = math.min(range or PLANT_RAY_RANGE, PLANT_RAY_RANGE)
	const result = workspace:Raycast(origin, direction.Unit * distance, plantParams)
	if not result then
		return
	end

	if GunRules.IsPlantable(result.Instance) then
		GunRules.PlantAt(result.Position, gunName)
	end
end

return GunRules
