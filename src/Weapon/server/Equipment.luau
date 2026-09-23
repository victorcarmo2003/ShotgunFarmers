--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local GunRules = require(ServerScriptService.server.Weapon.GunRules)
local Modux = require(ServerScriptService.server.Modux)

export type SlotIndex = number

const SLOT_COUNT = 3
const VISUAL_WAIT_TIMEOUT = 5

const DEFAULT_LOADOUT: { [SlotIndex]: GetGun.GunNames } = {
	[1] = "M6Bean",
}

const SLOT_BY_POSE_KIND: { [GetGun.PoseKind]: SlotIndex } = {
	Firearm = 1,
	Throwable = 2,
	Melee = 3,
}

const Equipment = Modux.Component("Equipment", { Tag = "Equipment", Require = { "NetService" } })

local function createWeaponInstance(gunName: string): Model
	const model = Instance.new("Model")
	model.Name = gunName

	const root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.Size = Vector3.one
	root.Parent = model

	model.PrimaryPart = root
	model.Parent = ServerStorage

	return model
end

local function attachWeaponVisual(character: Model, gunData: GetGun.GunData): Model?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const weapons = assets and assets:FindFirstChild("Weapons")
	const asset = weapons and weapons:FindFirstChild(gunData.DisplayName)
	if not asset or not asset:IsA("Model") then
		return nil
	end

	const targetPart = character:WaitForChild("HumanoidRootPart", VISUAL_WAIT_TIMEOUT)
	if not targetPart or not targetPart:IsA("BasePart") then
		return nil
	end

	const visual = asset:Clone() :: Model
	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
		end
	end

	const handle = visual.PrimaryPart
	if handle then
		const bodyWeld = handle:FindFirstChild("BodyWeld")
		if bodyWeld and bodyWeld:IsA("Motor6D") then
			bodyWeld.Part0 = targetPart
			bodyWeld.Part1 = handle
		else
			const weld = Instance.new("WeldConstraint")
			weld.Part0 = targetPart
			weld.Part1 = handle
			weld.Parent = visual
		end
	end

	visual.Parent = character
	return visual
end

function Equipment:Setup()
	self.Owner = self.Instance :: Player
	self.Loadout = table.clone(DEFAULT_LOADOUT) :: { [SlotIndex]: GetGun.GunNames }
	self.Ammo = table.create(SLOT_COUNT, 0) :: { number }
	self.Weapons = {} :: { [SlotIndex]: Model }
	self.ActiveSlot = 1 :: SlotIndex
	self.WeaponID = 0 :: number
	self.Equipped = nil :: GetGun.GunNames?
	self.Visual = nil :: Model?
	self.DrawUntil = 0 :: number

	self.Destroyed = false :: boolean
end

function Equipment:Publish()
	if not self.Dependencies.NetService:IsReady(self.Owner) then
		return
	end

	const slots = table.create(SLOT_COUNT, 0)
	for slot = 1, SLOT_COUNT do
		const gunName = self.Loadout[slot]
		const gunData = gunName and GetGun.ByName(gunName)
		slots[slot] = if gunData then gunData.ID else 0
	end

	self.Libs.Net.Weapon.Loadout:fireClient(self.Owner, {
		Slots = slots,
		ActiveSlot = self.ActiveSlot,
		Ammo = self.Ammo,
		DrawEndsAt = self.DrawUntil,
	})
end

function Equipment:ActiveGun(): (Instance?, string?)
	const slot = self.ActiveSlot
	return self.Weapons[slot], self.Loadout[slot]
end

function Equipment:ActiveAmmo(): number
	return self.Ammo[self.ActiveSlot] or 0
end

function Equipment:ConsumeAmmo(amount: number): boolean
	const slot = self.ActiveSlot
	const current = self.Ammo[slot] or 0
	if current < amount then
		return false
	end

	self.Ammo[slot] = current - amount
	self:Publish()
	return true
end

function Equipment:DrawEndsAt(): number
	return self.DrawUntil
end

function Equipment:StartDraw(gunData: GetGun.GunData?)
	self.DrawUntil = workspace:GetServerTimeNow() + GunRules.DrawTime(gunData)
end

function Equipment:ResetAmmo()
	for slot = 1, SLOT_COUNT do
		const gunName = self.Loadout[slot]
		const gunData = gunName and GetGun.ByName(gunName)
		self.Ammo[slot] = if gunData then gunData.Amount else 0
	end
end

function Equipment:AddAmmo(gunName: string, amount: number)
	for slot = 1, SLOT_COUNT do
		if self.Loadout[slot] ~= gunName then
			continue
		end

		self.Ammo[slot] = (self.Ammo[slot] or 0) + amount
		self:Publish()
		return
	end
end

function Equipment:HasGun(gunName: string): boolean
	for slot = 1, SLOT_COUNT do
		if self.Loadout[slot] == gunName then
			return true
		end
	end

	return false
end

function Equipment:RefreshVisual()
	if self.Visual then
		self.Visual:Destroy()
		self.Visual = nil
	end

	const character = self.Owner.Character
	const gunName = self.Equipped
	const gunData = if gunName then GetGun.ByName(gunName) else nil
	if not character or not gunName or not gunData then
		return
	end

	self:MountVisual(character, gunName, gunData)
end

function Equipment:MountVisual(character: Model, gunName: GetGun.GunNames, gunData: GetGun.GunData)
	task.spawn(function()
		const visual = attachWeaponVisual(character, gunData)
		if not self.Destroyed and self.Owner.Character == character and self.Equipped == gunName then
			self.Visual = visual
		elseif visual then
			visual:Destroy()
		end
	end)
end

function Equipment:Spawn(gunName: GetGun.GunNames): Model
	const weapon = createWeaponInstance(gunName)
	weapon:SetAttribute("GunName", gunName)

	self.Components.Gun:Create(weapon)
	return weapon
end

function Equipment:Clear(slot: SlotIndex)
	const weapon = self.Weapons[slot]
	if weapon then
		self.Components.Gun:Destroy(weapon)
		weapon:Destroy()
		self.Weapons[slot] = nil
	end

	self.Loadout[slot] = nil
	self.Ammo[slot] = 0
end

function Equipment:Equip(slot: SlotIndex): boolean
	const gunName = self.Loadout[slot]
	const weapon = self.Weapons[slot]
	if not gunName or not weapon then
		return false
	end

	const gunData = GetGun.ByName(gunName)
	if not gunData then
		return false
	end

	self.Equipped = gunName
	self.WeaponID = gunData.ID
	self:RefreshVisual()
	self:StartDraw(gunData)

	return true
end

function Equipment:SwitchSlot(slot: SlotIndex): boolean
	if not self:Equip(slot) then
		return false
	end

	self.ActiveSlot = slot
	self:Publish()
	return true
end

function Equipment:Grant(gunName: GetGun.GunNames): boolean
	const gunData = GetGun.ByName(gunName)
	if not gunData then
		return false
	end

	const slot = SLOT_BY_POSE_KIND[gunData.PoseKind]
	if not slot then
		return false
	end

	self:Clear(slot)
	self.Loadout[slot] = gunName
	self.Ammo[slot] = gunData.Amount
	self.Weapons[slot] = self:Spawn(gunName)
	self:SwitchSlot(slot)

	return true
end

function Equipment:DiscardActive(): boolean
	const slot = self.ActiveSlot
	if not self.Loadout[slot] then
		return false
	end

	self:Clear(slot)
	return self:Grant("Shovel")
end

function Equipment:Respawn()
	const gunName = self.Equipped

	self:ResetAmmo()
	self:RefreshVisual()
	self:StartDraw(if gunName then GetGun.ByName(gunName) else nil)
	self:Publish()
end

Equipment:OnInit(function(self)
	self:Setup()

	for slot = 1, SLOT_COUNT do
		const gunName = self.Loadout[slot]
		if gunName then
			self.Weapons[slot] = self:Spawn(gunName)
		end
	end

	self:ResetAmmo()
	self:SwitchSlot(self.ActiveSlot)

	self.Owner.CharacterAdded:Connect(function()
		self:Respawn()
	end)
end)

Equipment:OnDestroy(function(self)
	self.Destroyed = true

	for slot = 1, SLOT_COUNT do
		self:Clear(slot)
	end

	if self.Visual then
		self.Visual:Destroy()
		self.Visual = nil
	end
end)

return Equipment
