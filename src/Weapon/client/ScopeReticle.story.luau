--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local ScopeReticle = require(script.Parent.ScopeReticle)

const create = Vide.create

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Thickness = UILabs.Slider(4, 1, 10, 1),
		Transparency = UILabs.Slider(0.15, 0, 1, 0.01),
		Size = UILabs.Slider(0.8, 0.2, 1, 0.01),
		Color = Color3.fromRGB(12, 12, 14),
		Accent = Color3.fromRGB(255, 55, 45),
		Background = Color3.fromRGB(140, 195, 255),
	},
}, function(props: UILabs.VideProps)
	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = function()
			return props.controls.Background()
		end,
		BorderSizePixel = 0,

		create("Frame")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = function()
				const size = props.controls.Size()
				return UDim2.fromScale(size, size)
			end,
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundTransparency = 1,

			ScopeReticle({
				Thickness = function()
					return props.controls.Thickness()
				end,
				Transparency = function()
					return props.controls.Transparency()
				end,
				Color = function()
					return props.controls.Color()
				end,
				Accent = function()
					return props.controls.Accent()
				end,
			}),
		}),
	})
end)
