--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

const create = Vide.create
const source = Vide.source

export type Props = {
	Label: string,
	Value: () -> number,
}

return function(props: Props): Frame
	const hovered = source(false)

	return create("Frame")({
		Size = UDim2.fromOffset(220, 64),
		BackgroundColor3 = function()
			return if hovered() then Color3.fromRGB(46, 46, 52) else Color3.fromRGB(32, 32, 36)
		end,
		MouseEnter = function()
			hovered(true)
		end,
		MouseLeave = function()
			hovered(false)
		end,

		create("UICorner")({ CornerRadius = UDim.new(0, 8) }),

		create("TextLabel")({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 18,
			TextColor3 = Color3.fromRGB(235, 235, 240),
			Text = function()
				return `{props.Label}: {props.Value()}`
			end,
		}),
	})
end
