--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modux = require(ReplicatedStorage.Shared.Modux)

local VitalComponent =
	Modux.Component("VitalComponent"):Tag("VitalComponent"):ClassName("Player"):Import("VitalService")
type Self = typeof(VitalComponent)

export type VitalAttributes = "Armor" | "Health"

VitalComponent.OnDie = VitalComponent.Signal.new() :: Modux.Signal<Player>

VitalComponent.Die = function(self: Self)
	self.VitalService:OnPlayerDie(self.Instance)
end

VitalComponent.ReplicateAll = function(self: Self)
	self.Package:sendKey("Armor", self.Armor, self.Instance)
	self.Package:sendKey("Health", self.Health, self.Instance)
end

VitalComponent.ReplicateKey = function(self: Self, Key: VitalAttributes)
	self.Package:sendKey(Key, self[Key], self.Instance)
end

VitalComponent.TakeDamage = function(self: Self, Amount: number)
	local targetHealth = self.Health - Amount
	if targetHealth <= 0 then
		self.CanHeal = false
		self.Health = 0
		self.Package:sendKey("Health", self.Health, self.Instance)
		self:Die()
		return false
	end
	targetHealth = math.clamp(targetHealth, 0, 100)
	self.Health = targetHealth
	self.Package:sendKey("Health", self.Health, self.Instance)
	return true
end

VitalComponent.SetArmor = function(self: Self, Amount: number)
	self.Armor = Amount
	self.Package:sendKey("Armor", self.Armor, self.Instance)
	return true
end

VitalComponent.Heal = function(self: Self, Amount: number)
	local targetHealth = self.Health + Amount
	targetHealth = math.clamp(targetHealth, 0, 100)
	self.Health = targetHealth
	self.Package:sendKey("Health", self.Health, self.Instance)
	return true
end

local function resetVitals(self)
	self.Armor = 0
	self.Health = 100
	self.Stamina = 100
	self.CanHeal = true
end

VitalComponent:OnInit(function(self)
	resetVitals(self)
	self.Package = self.Network.Packages.VitalKey

	self:Cleanup((self.Instance :: Player).CharacterAdded:Connect(function()
		resetVitals(self)
		self:ReplicateAll()
	end))
end)

VitalComponent:OnTick(function(self, deltaTime: number)
	if self.CanHeal then
		self:Heal(0.5)
	end
end, Modux.TickRate.Hz1)

return VitalComponent
