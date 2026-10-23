--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local SeedSettings = require(ReplicatedStorage.shared.Seed.SeedSettings)
local GunRules = require(ServerScriptService.server.Weapon.GunRules)
local Modux = require(ServerScriptService.server.Modux)

const PRACTICE_MODE = "Practice"
const TICK_RATE = 2

type Slot = {
	Seed: BasePart?,
	NextAt: number,
	PlantedAt: number,
	Last: string?,
}

const RestockService = Modux.Service("RestockService", {
	Require = { "EnvironmentService", "GameStateService", "ServerRoleService" },
	Priority = 290,
})

function RestockService:Setup()
	self.Enabled = false :: boolean
	self.Slots = {} :: { [Instance]: Slot }
	self.Firearms = {} :: { string }
	self.Throwables = {} :: { string }
	self.Warned = false :: boolean
end

function RestockService:BuildPool()
	for name, gunData in GetGun.All do
		if gunData.Disabled or gunData.SeedModel == "" then
			continue
		end
		if gunData.PoseKind == "Firearm" then
			table.insert(self.Firearms, name)
		elseif gunData.PoseKind == "Throwable" then
			table.insert(self.Throwables, name)
		end
	end
	table.sort(self.Firearms)
	table.sort(self.Throwables)
end

function RestockService:Crates(): { Instance }
	const root = self.Dependencies.EnvironmentService:GetRoot()
	const crates: { Instance } = {}
	if not root or not root:IsDescendantOf(workspace) then
		return crates
	end

	for _, instance in CollectionService:GetTagged(SeedSettings.RESTOCK_TAG) do
		if instance:IsDescendantOf(root) then
			table.insert(crates, instance)
		end
	end
	return crates
end

local function plantPoint(crate: Instance): Vector3?
	const attachment = crate:FindFirstChild(SeedSettings.RESTOCK_POINT, true)
	if attachment and attachment:IsA("Attachment") then
		return attachment.WorldPosition
	end

	const soil = crate:FindFirstChild(SeedSettings.RESTOCK_SOIL, true)
	if soil and soil:IsA("BasePart") then
		return (soil.CFrame * CFrame.new(0, soil.Size.Y / 2, 0)).Position
	end

	if crate:IsA("BasePart") then
		return crate.Position + Vector3.new(0, crate.Size.Y / 2, 0)
	end
	if crate:IsA("Model") then
		const pivot, size = crate:GetBoundingBox()
		return pivot.Position + Vector3.new(0, size.Y / 2, 0)
	end
	return nil
end

function RestockService:PickGun(last: string?): string
	const throwable = #self.Throwables > 0 and math.random() < SeedSettings.RESTOCK_THROWABLE_CHANCE
	const pool = if throwable then self.Throwables else self.Firearms
	if #pool == 1 then
		return pool[1]
	end

	local name = pool[math.random(1, #pool)]
	while name == last do
		name = pool[math.random(1, #pool)]
	end
	return name
end

local function mark(crate: Instance, active: boolean, stocked: boolean)
	crate:SetAttribute(SeedSettings.RESTOCK_ACTIVE_ATTRIBUTE, active)
	crate:SetAttribute(SeedSettings.RESTOCK_STOCKED_ATTRIBUTE, stocked)
end

function RestockService:Plant(crate: Instance, slot: Slot)
	const point = plantPoint(crate)
	if not point then
		return
	end

	const gunName = self:PickGun(slot.Last)
	const seed = GunRules.PlantAt(point, gunName, "Restock")
	slot.Seed = seed
	slot.Last = gunName
	slot.PlantedAt = os.clock()
	mark(crate, true, seed ~= nil)
	if not seed then
		slot.NextAt = os.clock() + SeedSettings.RESTOCK_DELAY
	end
end

function RestockService:Step()
	const crates = self:Crates()
	if #crates == 0 or #self.Firearms == 0 then
		if not self.Warned and #self.Firearms == 0 then
			self.Warned = true
			warn("[RestockService] nenhuma arma Firearm com SeedModel; caixotes de reestoque vazios")
		end
		return
	end

	const now = os.clock()
	const alive: { [Instance]: boolean } = {}
	for _, crate in crates do
		alive[crate] = true

		local slot = self.Slots[crate]
		if not slot then
			const created: Slot = { Seed = nil, NextAt = now, PlantedAt = now, Last = nil }
			self.Slots[crate] = created
			mark(crate, true, false)
			slot = created
		end

		const seed = slot.Seed
		if seed and not seed.Parent then
			slot.Seed = nil
			const collected = now - slot.PlantedAt < SeedSettings.SEED_LIFETIME
			slot.NextAt = now + if collected then SeedSettings.RESTOCK_COOLDOWN else SeedSettings.RESTOCK_DELAY
			mark(crate, true, false)
		end

		if slot.Seed == nil and now >= slot.NextAt then
			self:Plant(crate, slot)
		end
	end

	for crate, slot in self.Slots do
		if not alive[crate] then
			if slot.Seed and slot.Seed.Parent then
				slot.Seed:Destroy()
			end
			mark(crate, false, false)
			self.Slots[crate] = nil
		end
	end
end

function RestockService:Clear()
	for crate, slot in self.Slots do
		if slot.Seed and slot.Seed.Parent then
			slot.Seed:Destroy()
		end
		mark(crate, false, false)
	end
	table.clear(self.Slots)
end

function RestockService:Refresh()
	const roles = self.Dependencies.ServerRoleService
	const config = if roles:IsMatch() then roles:GetConfig() else nil
	const active = config ~= nil
		and config.Mode ~= PRACTICE_MODE
		and self.Dependencies.GameStateService:Can("Combat")

	if active == self.Enabled then
		return
	end
	self.Enabled = active

	if active then
		self:Step()
	else
		self:Clear()
	end
end

RestockService:OnInit(function(self)
	self:Setup()
	self:BuildPool()
end)

RestockService:OnStart(function(self)
	self.Dependencies.ServerRoleService:OnReady(function()
		self:Refresh()
	end)

	self.Dependencies.GameStateService:OnChanged(function()
		self:Refresh()
	end)

	self.Dependencies.EnvironmentService.MapChanged:Connect(function()
		self:Clear()
	end)
end)

RestockService:OnTick(function(self)
	if self.Enabled then
		self:Step()
	end
end, TICK_RATE)

return RestockService
