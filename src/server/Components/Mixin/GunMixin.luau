local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local GameSettings = require(ReplicatedStorage.Shared.Settings.GameSettings)

local GunMixin = Modux.Mixin("GunMixin")
local SOUND_CLEANUP_FALLBACK = 10
local PLANTABLE_TAG = "Farmland"
local PLANT_RAY_RANGE = 150
local plantRaycastParams = RaycastParams.new()
plantRaycastParams.FilterType = Enum.RaycastFilterType.Exclude

export type SeedProp = BasePart

GunMixin.Shoot = function(
	self,
	Shooter: Player,
	Equipment: any,
	origin: Vector3,
	direction: Vector3,
	claimedPellets: { any },
	timestamp: number,
	isAiming: boolean
): { { Player: Player, HitPart: number } }
	warn(`[GunMixin] Shoot não implementado para "{self.ID}" -- sobrescreva Shoot no componente da arma.`)
	return {}
end

GunMixin.GetEffectiveSpread = function(self, Shooter: Player, isAiming: boolean): number
	local spread = self.Spread

	local character = Shooter.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.MoveDirection.Magnitude > 0.05 then
		spread *= GameSettings.MovingSpreadMultiplier
	end

	if isAiming then
		spread *= GameSettings.AimSpreadMultiplier
	end

	return spread
end

GunMixin.CanShoot = function(self, Equipment: any): boolean
	local hasAmmo = Equipment.SlotAmmo[Equipment.ActiveSlot] > 0
	local offCooldown = (workspace:GetServerTimeNow() - self.lastshoot) >= self.FireRate
	return hasAmmo and offCooldown
end

GunMixin.ConsumeAndReplicateAmmo = function(self, Equipment: any)
	local slot = Equipment.ActiveSlot
	local newAmmo = math.max(Equipment.SlotAmmo[slot] - 1, 0)
	Equipment.SlotAmmo[slot] = newAmmo
	self.lastshoot = workspace:GetServerTimeNow()
	Equipment.Package:sendKey("Ammo", { Slot = slot, Amount = newAmmo }, Equipment.Instance)
end

GunMixin.RandomSpread = function(self, direction: Vector3, spread: number): Vector3
	if spread <= 0 then
		return direction
	end
	local randomAngleX = math.rad((math.random() - 0.5) * 2 * spread)
	local randomAngleY = math.rad((math.random() - 0.5) * 2 * spread)
	local baseCFrame = CFrame.lookAt(Vector3.zero, direction)
	return (baseCFrame * CFrame.Angles(randomAngleX, randomAngleY, 0)).LookVector
end

local function getSeedsFolder(): Folder
	local folder = workspace:FindFirstChild("Seeds") :: Folder?
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Seeds"
		folder.Parent = workspace
	end
	return folder :: Folder
end

GunMixin.PlantAt = function(self, Position: Vector3)
	
	local dirt = ReplicatedStorage.Assets.Seeds.Dirt:Clone() :: SeedProp
	dirt:PivotTo(CFrame.new(Position) * dirt.CFrame.Rotation)
	dirt:SetAttribute("GunName", self.GunName)
	dirt:SetAttribute("PlantedAt", workspace:GetServerTimeNow())
	dirt.Parent = getSeedsFolder()
	CollectionService:AddTag(dirt, "SeedComponent")

end

GunMixin.TryPlant = function(self, origin: Vector3, direction: Vector3, Shooter: Player)
	if direction.Magnitude < 0.5 then
		return
	end

	plantRaycastParams.FilterDescendantsInstances = if Shooter.Character then { Shooter.Character } else {}

	local result = workspace:Raycast(origin, direction.Unit * PLANT_RAY_RANGE, plantRaycastParams)
	if not result then
		return
	end

	local hasTag = CollectionService:HasTag(result.Instance, PLANTABLE_TAG)
	
	if hasTag then
		self:PlantAt(result.Position)
	end
end

GunMixin.GetOrigin = function(self): Vector3
	local muzzle = self.Instance.Muzzle
	if not muzzle then
		return self.Instance.PrimaryPart.Position
	end
	return muzzle.WorldPosition
end

GunMixin.PlayShootSound = function(self, Shooter: Player, soundName: string)
	task.spawn(function()
		if soundName == "" then
			return
		end

		local soundsFolder = ReplicatedStorage:FindFirstChild("Assets")
		soundsFolder = soundsFolder and soundsFolder:FindFirstChild("Sounds")
		local soundTemplate = soundsFolder and soundsFolder:FindFirstChild(soundName)
		if not soundTemplate or not soundTemplate:IsA("Sound") then
			return
		end

		local equipment = self:GetComponent(Shooter, "EquipmentComponent")
		local weaponVisual = equipment and equipment.WeaponVisual
		local soundParent = weaponVisual and weaponVisual.PrimaryPart
		if not soundParent then
			local character = Shooter.Character
			soundParent = character and character:FindFirstChild("HumanoidRootPart")
		end
		if not soundParent then
			return
		end

		local sound = soundTemplate:Clone() :: Sound
		sound.Parent = soundParent
		sound:Play()
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		Debris:AddItem(sound, SOUND_CLEANUP_FALLBACK)
	end)
end

GunMixin:OnStart(function(self)
	self.Damage = 0
	self.ShootAmount = 1
	self.Spread = 0
	self.FireRate = 0
	self.Knockback = 0
	self.ShootSoundName = "" :: string
	self.GunName = "" :: string
	self.lastshoot = workspace:GetServerTimeNow() :: number
end)

GunMixin:OnDestroy(function(self) end)

return GunMixin
