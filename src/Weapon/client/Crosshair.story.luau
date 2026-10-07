--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Crosshair = require(script.Parent.Crosshair)

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Movement = UILabs.Slider(0, 0, 1, 0.01),
		Firing = UILabs.Slider(0.3, 0, 1, 0.01),
		Dot = true,
		Outer = true,
	},
}, function(props: UILabs.VideProps)
	const base = Crosshair.Defaults()

	return Crosshair.new({
		Config = function()
			const config = table.clone(base)
			config.Dot = props.controls.Dot()
			config.Outer = table.clone(base.Outer)
			config.Outer.Show = props.controls.Outer()
			return config
		end,
		Movement = function()
			return props.controls.Movement()
		end,
		Firing = function()
			return props.controls.Firing()
		end,
	})
end)
