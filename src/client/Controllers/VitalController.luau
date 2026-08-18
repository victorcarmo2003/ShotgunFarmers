local StarterPlayer = game:GetService("StarterPlayer")
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local VitalController = Modux.Controller("VitalController"):Import("ColorCorrectionController")
type Self = typeof(VitalController)

local clampSaturation = function(health: number, maxHealth: number): number
	maxHealth = math.max(maxHealth, 1)
	local percent = math.clamp(health / maxHealth, 0, 1)
	if percent >= 0.5 then
		return 0.5
	end
	local t = percent / 0.5
	return -2 + (1.5 * t)
end

VitalController.GetScopes = function(self: Self): Fusion.Scope
	return self.Scope
end

VitalController.OnUpdateHealth = function(self: Self, amount: number)
	local clamped = clampSaturation(amount, self.MaxHealth)
	self.ColorCorrectionController:SetSaturation(clamped)
end

VitalController.UpdateHealth = function(self: Self, amount: number)
	local health = math.min(amount, self.MaxHealth)
	self.Health:set(health)
	self:OnUpdateHealth(health)
end

VitalController.UpdateArmor = function(self: Self, amount: number)
	local armor = math.min(amount, self.MaxArmor)
	self.Armor:set(armor)
end

VitalController:OnInit(function(self)
	local scoped = Fusion.scoped(Fusion)
	self.Scope = scoped
	self.Health = scoped:Value(100)
	self.Armor = scoped:Value(100)
	self.OnMobile = scoped:Value(false)
	self.MaxHealth = 100
	self.MaxArmor = 100

	self.Network.Packages.VitalKey:onKey(function(key, value)
		if key == "Health" then
			self:UpdateHealth(value)
		elseif key == "Armor" then
			self:UpdateArmor(value)
		end
	end)
end)

VitalController:OnStart(function(self)
	task.spawn(function()
		local Vitals = self.Network.Packages.GetVitals:request()
		if Vitals then
			self.Armor:set(Vitals.Armor)
			self.Stamina = Vitals.Stamina
			self.MaxHealth = (Vitals.MaxHealth :: number) or 100
			self.MaxStamina = (Vitals.MaxStamina :: number) or 100
			self:UpdateHealth(Vitals.Health)
		end
	end)
end)

return VitalController
