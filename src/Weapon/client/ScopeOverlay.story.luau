--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local ScopeOverlay = require(script.Parent.ScopeOverlay)

const create = Vide.create

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Visible = true,
		HousingColor = Color3.fromRGB(70, 5, 45),
	},
}, function(props: UILabs.VideProps)
	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(140, 195, 255),
		BorderSizePixel = 0,

		ScopeOverlay.new({
			Visible = function()
				return props.controls.Visible()
			end,
			HousingColor = function()
				return props.controls.HousingColor()
			end,
		}),
	})
end)
