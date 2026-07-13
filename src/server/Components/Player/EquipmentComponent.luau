local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local GetGun = require(ReplicatedStorage.Shared.Utils.GetGun)

local EquipmentComponent = Modux.Component("EquipmentComponent"):Tag("EquipmentComponent"):ClassName("Player")

local WEAPON_VISUAL_WAIT_TIMEOUT = 5

export type SlotIndex = number

local DEFAULT_LOADOUT: { [SlotIndex]: GetGun.GunNames } = {
	[1] = "Shotgun",
	[2] = "Peavolver",
}

local MAX_LOADOUT_SLOTS = 3

local function createWeaponInstance(GunName: string): Model
	local model = Instance.new("Model")
	model.Name = GunName

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.Transparency = 1
	root.Size = Vector3.new(1, 1, 1)
	root.Parent = model

	model.PrimaryPart = root
	model.Parent = ServerStorage

	return model
end

local function attachWeaponVisual(character: Model, gunData: GetGun.GunData): Model?
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	local weaponsFolder = assetsFolder and assetsFolder:FindFirstChild("Weapons")
	local weaponAsset = weaponsFolder and weaponsFolder:FindFirstChild(gunData.DisplayName)
	if not weaponAsset then
		return nil
	end
	local rightArm = character:WaitForChild("Right Arm", WEAPON_VISUAL_WAIT_TIMEOUT) :: BasePart?
	local rightGrip = rightArm
		and rightArm:WaitForChild("RightGripAttachment", WEAPON_VISUAL_WAIT_TIMEOUT) :: Attachment?
	if not rightArm or not rightGrip then
		return nil
	end

	local weaponModel = weaponAsset:Clone() :: Model
	for _, descendant in weaponModel:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
		end
	end

	local weaponGrip = weaponModel:FindFirstChild("Grip", true) :: Attachment?
	if weaponGrip and weaponModel.PrimaryPart then
		weaponModel:PivotTo(rightGrip.WorldCFrame * weaponGrip.CFrame:Inverse())
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = rightArm
		weld.Part1 = weaponModel.PrimaryPart
		weld.Parent = weaponModel
	end

	weaponModel.Parent = character
	return weaponModel
end

EquipmentComponent.RefreshVisual = function(self)
	if self.WeaponVisual then
		self.WeaponVisual:Destroy()
		self.WeaponVisual = nil
	end

	local player = self.Instance :: Player
	local character = player.Character
	local gunName = self.EquippedGun
	local gunData = gunName and GetGun:GetByName(gunName)
	if not character or not gunData then
		return
	end

	task.spawn(function()
		local visual = attachWeaponVisual(character, gunData)
		if not self._destroyed and player.Character == character and self.EquippedGun == gunName then
			self.WeaponVisual = visual
		elseif visual then
			visual:Destroy()
		end
	end)
end
EquipmentComponent.EquipGun = function(self, Slot: SlotIndex): boolean
	local gunName = self.Loadout[Slot]
	local weaponInstance = self.SlotWeaponInstance[Slot]
	if not gunName or not weaponInstance then
		return false
	end

	local gunData = GetGun:GetByName(gunName)
	if not gunData then
		return false
	end

	self.EquippedGun = gunName
	self.WeaponID = gunData.ID
	self.WeaponInstance = weaponInstance
	self.EquippedGunComponentID = gunName .. "Component"

	self.Package:sendKey("WeaponID", self.WeaponID, self.Instance)

	self:RefreshVisual()

	return true
end

EquipmentComponent.ResetAmmo = function(self)
	for slot, gunName in self.Loadout do
		local gunData = GetGun:GetByName(gunName)
		local fullAmmo = gunData and gunData.Amount or 0
		self.SlotAmmo[slot] = fullAmmo
		self.Package:sendKey("Ammo", { Slot = slot, Amount = fullAmmo }, self.Instance)
	end
end

EquipmentComponent.SwitchSlot = function(self, Slot: SlotIndex): boolean
	if not self:EquipGun(Slot) then
		return false
	end

	self.ActiveSlot = Slot
	self.Package:sendKey("ActiveSlot", self.ActiveSlot, self.Instance)

	return true
end

EquipmentComponent.HasGun = function(self, GunName: string): boolean
	for _, loadoutGun in self.Loadout do
		if loadoutGun == GunName then
			return true
		end
	end
	return false
end

EquipmentComponent.AddAmmo = function(self, GunName: string, Amount: number)
	for slot, loadoutGun in self.Loadout do
		if loadoutGun == GunName then
			--local gunData = GetGun:GetByName(GunName :: GetGun.GunNames)
			--local maxAmmo = gunData and gunData.Amount or self.SlotAmmo[slot]
			local newAmmo = self.SlotAmmo[slot] + Amount --math.min(self.SlotAmmo[slot] + Amount, maxAmmo)
			self.SlotAmmo[slot] = newAmmo
			self.Package:sendKey("Ammo", { Slot = slot, Amount = newAmmo }, self.Instance)
			return
		end
	end
end

EquipmentComponent.GrantWeapon = function(self, GunName: GetGun.GunNames): boolean
	local gunData = GetGun:GetByName(GunName)
	if not gunData then
		return false
	end

	local freeSlot: SlotIndex? = nil
	for slot = 1, MAX_LOADOUT_SLOTS do
		if not self.Loadout[slot] then
			freeSlot = slot
			break
		end
	end
	if not freeSlot then
		return false
	end

	self.Loadout[freeSlot] = GunName
	self.SlotAmmo[freeSlot] = gunData.Amount

	local weaponInstance = createWeaponInstance(GunName)
	CollectionService:AddTag(weaponInstance, GunName)
	self.SlotWeaponInstance[freeSlot] = weaponInstance

	self:SwitchSlot(freeSlot)

	return true
end

EquipmentComponent:OnInit(function(self)
	self.EquippedGun = nil :: GetGun.GunNames?
	self.WeaponID = 0 :: number
	self.WeaponInstance = nil :: Instance?
	self.WeaponVisual = nil :: Model?
	self.EquippedGunComponentID = nil :: string?
	self.Loadout = DEFAULT_LOADOUT :: { [SlotIndex]: GetGun.GunNames }
	self.ActiveSlot = 1 :: SlotIndex
	self.Package = self.Network.Packages.WeaponKey --modux ignore line
	self._destroyed = false :: boolean

	self.SlotAmmo = {} :: { [SlotIndex]: number }
	self.SlotWeaponInstance = {} :: { [SlotIndex]: Model }
	for slot, gunName in self.Loadout do
		local gunData = GetGun:GetByName(gunName)
		self.SlotAmmo[slot] = gunData and gunData.Amount or 0

		local weaponInstance = createWeaponInstance(gunName)
		CollectionService:AddTag(weaponInstance, gunName)
		self.SlotWeaponInstance[slot] = weaponInstance
	end

	self:Cleanup((self.Instance :: Player).CharacterAdded:Connect(function()
		self:ResetAmmo()
		self:RefreshVisual()
	end))

	self:EquipGun(self.ActiveSlot)
	self.Package:sendKey("ActiveSlot", self.ActiveSlot, self.Instance)
end)

EquipmentComponent:OnStart(function(self) end)

EquipmentComponent:OnDestroy(function(self)
	self._destroyed = true
	for _, weaponInstance in self.SlotWeaponInstance do
		weaponInstance:Destroy()
	end
	if self.WeaponVisual then
		self.WeaponVisual:Destroy()
	end
end)

return EquipmentComponent
