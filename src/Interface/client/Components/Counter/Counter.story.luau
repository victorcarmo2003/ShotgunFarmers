local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Counter = require(script.Parent)

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Label = "Coins",
		Value = 120,
	},
}, function(props)
	return Counter({
		Label = props.controls.Label(),
		Value = function()
			return props.controls.Value()
		end,
	})
end)
