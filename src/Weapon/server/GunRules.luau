--!strict
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameSettings = require(ReplicatedStorage.shared.Settings.GameSettings)
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)

const SOUND_CLEANUP_FALLBACK = 10
const PLANTABLE_TAG = "Farmland"
const PLANT_RAY_RANGE = 150

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
	now: number
): (boolean, string?)
	if ammo <= 0 then
		return false, "NoAmmo"
	end

	if now - lastShoot < gunData.FireRate then
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

function GunRules.PlantAt(position: Vector3, gunName: string)
	const template = dirtTemplate()
	if not template then
		warn("[GunRules] Assets.Seeds.Dirt nao encontrado; nada plantado")
		return
	end

	const dirt = template:Clone() :: BasePart
	dirt:PivotTo(CFrame.new(position) * dirt.CFrame.Rotation)
	dirt:SetAttribute("GunName", gunName)
	dirt:SetAttribute("PlantedAt", workspace:GetServerTimeNow())
	dirt.Parent = seedsFolder()
	CollectionService:AddTag(dirt, SEED_TAG)
end

function GunRules.TryPlant(shooter: Player, origin: Vector3, direction: Vector3, gunName: string)
	if direction.Magnitude < MIN_DIRECTION then
		return
	end

	const filter: { Instance } = {}
	const character = shooter.Character
	if character then
		table.insert(filter, character)
	end
	plantParams.FilterDescendantsInstances = filter

	const result = workspace:Raycast(origin, direction.Unit * PLANT_RAY_RANGE, plantParams)
	if not result then
		return
	end

	if CollectionService:HasTag(result.Instance, PLANTABLE_TAG) then
		GunRules.PlantAt(result.Position, gunName)
	end
end

local function soundTemplate(name: string): Sound?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const sounds = assets and assets:FindFirstChild("Sounds")
	const sound = sounds and sounds:FindFirstChild(name)
	if sound and sound:IsA("Sound") then
		return sound
	end

	return nil
end

function GunRules.PlayShootSound(shooter: Player, soundName: string, visual: Model?)
	if soundName == "" then
		return
	end

	const template = soundTemplate(soundName)
	if not template then
		warn(`[GunRules] som "{soundName}" nao esta em Assets.Sounds`)
		return
	end

	local parent: Instance? = visual and visual.PrimaryPart
	if not parent then
		const character = shooter.Character
		parent = character and character:FindFirstChild("HumanoidRootPart")
	end
	if not parent then
		return
	end

	const sound = template:Clone() :: Sound
	sound.Parent = parent
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, SOUND_CLEANUP_FALLBACK)
end

return GunRules
