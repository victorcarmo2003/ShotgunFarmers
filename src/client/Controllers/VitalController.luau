local Modux = require(game.ReplicatedStorage.Shared.Modux)
local VitalController = Modux.Controller("VitalController"):Import("ScreenController"):Import("UIAnimationsController")

VitalController.AutoConsume = function(self) end

VitalController.UpdateHealth = function(self, number: number)
	local healthConteiner = self.PlayerStatus.Health
	local text = healthConteiner.TextLabel
	text.Text = `HEALTH: {number}%`
end

VitalController:OnInit(function(self)
	self.Health = 100
	self.MaxHealth = 100
	self.Network.Packages.VitalKey:onKey(function(key, value)
		if key == "Health" then
			self.Health = value
			self:UpdateHealth(value)
		end
	end)
end)

VitalController:OnStart(function(self)
	local screenGui = self.ScreenController:GetGui()
	self.PlayerStatus = screenGui.Conteiner.Player
	task.spawn(function()
		local Vitals = self.Network.Packages.GetVitals:request()

		if Vitals then
			self.Armor = Vitals.Armor
			self.Health = Vitals.Health
			self.Stamina = Vitals.Stamina
			self.MaxHealth = (Vitals.MaxHealth :: number) or 100
			self.MaxStamina = (Vitals.MaxStamina :: number) or 100

			self:UpdateHealth(self.Health)
		end
	end)
end)

return VitalController
