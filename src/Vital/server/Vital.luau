--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const MAX_HEALTH = 100
const MAX_ARMOR = 100
const MAX_STAMINA = 100
const STAMINA_REGEN = 5

const HEALTH_REGEN = 0.125
const TICK_RATE = 4

const Vital = Modux.Component("Vital", { Tag = "Vital", Require = { "VitalService" } })

function Vital:Setup()
	self.Owner = self.Instance :: Player
	self.Health = MAX_HEALTH :: number
	self.Armor = 0 :: number
	self.Stamina = MAX_STAMINA :: number
	self.Alive = true :: boolean
end

function Vital:Publish()
	self.Libs.Net.Vital.Vitals:update(self.Owner.UserId, {
		Health = self.Health,
		Armor = self.Armor,
		Stamina = self.Stamina,
	})
end

function Vital:TakeDamage(amount: number): boolean
	if not self.Alive then
		return false
	end

	local incoming = math.max(amount, 0)
	if self.Armor > 0 then
		const absorbed = math.min(self.Armor, incoming)
		self.Armor -= absorbed
		incoming -= absorbed
	end

	self.Health = math.max(self.Health - incoming, 0)
	self:Publish()

	if self.Health > 0 then
		return true
	end

	self.Alive = false
	self.Dependencies.VitalService:Kill(self.Owner)
	return false
end

function Vital:NotifyRestored(before: number)
	if before < MAX_HEALTH and self.Health >= MAX_HEALTH then
		self.Dependencies.VitalService.Restored:Fire(self.Owner)
	end
end

function Vital:Heal(amount: number)
	if not self.Alive then
		return
	end
	const before = self.Health
	self.Health = math.min(self.Health + math.max(amount, 0), MAX_HEALTH)
	self:Publish()
	self:NotifyRestored(before)
end

function Vital:SetArmor(amount: number)
	self.Armor = math.clamp(amount, 0, MAX_ARMOR)
	self:Publish()
end

function Vital:SpendStamina(amount: number): boolean
	if self.Stamina < amount then
		return false
	end
	self.Stamina -= amount
	self:Publish()
	return true
end

function Vital:Revive()
	self.Health = MAX_HEALTH
	self.Armor = 0
	self.Stamina = MAX_STAMINA
	self.Alive = true
	self:Publish()
end

Vital:OnInit(function(self)
	self:Setup()
	self.Libs.Net.Vital.Vitals:add(self.Owner.UserId, {
		Health = self.Health,
		Armor = self.Armor,
		Stamina = self.Stamina,
	})
end)

Vital:OnTick(function(self)
	if not self.Alive then
		return
	end

	const stamina = math.min(self.Stamina + STAMINA_REGEN, MAX_STAMINA)
	const health = math.min(self.Health + HEALTH_REGEN, MAX_HEALTH)
	if stamina == self.Stamina and health == self.Health then
		return
	end

	const before = self.Health
	self.Stamina = stamina
	self.Health = health
	self:Publish()
	self:NotifyRestored(before)
end, TICK_RATE)

Vital:OnDestroy(function(self)
	if self.Libs.Net.Vital.Vitals:get(self.Owner.UserId) then
		self.Libs.Net.Vital.Vitals:remove(self.Owner.UserId)
	end
end)

return Vital
