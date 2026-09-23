--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Crosshair = require(script.Parent.Crosshair)

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		AimType = UILabs.Choose({ "Spread", "Default" }),
		SpreadRatio = UILabs.Slider(0.3, 0, 1, 0.01),
		IsAiming = false,
	},
}, function(props: UILabs.VideProps)
	return Crosshair({
		AimType = function()
			return props.controls.AimType()
		end,
		SpreadRatio = function()
			return props.controls.SpreadRatio()
		end,
		IsAiming = function()
			return props.controls.IsAiming()
		end,
	})
end)
