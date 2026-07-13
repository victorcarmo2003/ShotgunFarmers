--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modux = require(ReplicatedStorage.Shared.Modux)

local VitalComponent =
	Modux.Component("VitalComponent"):Tag("VitalComponent"):ClassName("Player"):Import("VitalService")

export type VitalAttributes = "Armor" | "Health"

VitalComponent.OnDie = VitalComponent.Signal.new() :: Modux.Signal<Player>

VitalComponent.Die = function(self)
	self.VitalService:OnPlayerDie(self.Instance)
end

VitalComponent.ReplicateAll = function(self)
	self.Package:sendKey("Armor", self.Armor, self.Instance)
	self.Package:sendKey("Health", self.Health, self.Instance)
end

VitalComponent.ReplicateKey = function(self, Key: VitalAttributes)
	self.Package:sendKey(Key, self[Key], self.Instance)
end

VitalComponent.TakeDamage = function(self, Amount: number)
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

VitalComponent.SetArmor = function(self, Amount: number)
	self.Armor = Amount
	self.Package:sendKey("Armor", self.Armor, self.Instance)
	return true
end

VitalComponent.Heal = function(self, Amount: number)
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

	-- VitalComponent é tageado no Player (não no Character, ver VitalService), então
	-- OnInit só roda uma vez por sessão -- sem isso, Health/CanHeal ficavam travados em
	-- 0/false pro resto da partida depois da PRIMEIRA morte (nada mais reseta esses
	-- campos). Consequência real: TakeDamage via HitService.ProcessFire matava de novo
	-- instantaneamente a qualquer dano (Health já <= 0) e o gate `shooterVital.Health <=
	-- 0` bloqueava até atirar -- o jogador ficava permanentemente preso depois de morrer
	-- uma vez. ReplicateAll aqui também corrige o ColorCorrectionController (a saturação
	-- fica presa no mínimo, tela dessaturada, porque o client nunca recebia Health de
	-- volta pra 100).
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
