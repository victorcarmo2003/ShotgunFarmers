--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const TICK_RATE = 30

const SensitivityController = Modux.Controller("SensitivityController", {
	Require = { "ArmsController", "OptionsController", "WeaponController" },
	Priority = 370,
})

function SensitivityController:Setup()
	self.Applied = nil :: number?
end

function SensitivityController:Multiplier(): number
	if not self.Dependencies.ArmsController.IsAiming() then
		return 1
	end

	const gunData = self.Dependencies.WeaponController:GunData()
	const options = self.Dependencies.OptionsController
	const scope = if gunData then gunData.Scope else nil
	if scope then
		return options:Get("SniperSensitivity") * (scope.Sensitivity or 1)
	end

	return options:Get("AimSensitivity")
end

function SensitivityController:Step()
	const value = self.Dependencies.OptionsController:Get("MouseSensitivity") * self:Multiplier()
	if value == self.Applied then
		return
	end

	self.Applied = value
	UserInputService.MouseDeltaSensitivity = value
end

SensitivityController:OnTick(function(self)
	self:Step()
end, TICK_RATE)

SensitivityController:OnInit(function(self)
	self:Setup()
end)

return SensitivityController
