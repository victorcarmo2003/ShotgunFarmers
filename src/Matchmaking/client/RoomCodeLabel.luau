--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.shared.Interface.Theme)
local CreateRaw = require(ReplicatedStorage.shared.Interface.CreateRaw)
local Vide = require(ReplicatedStorage.Packages.Vide)

const create = Vide.create

export type Props = {
	Code: () -> string,
}

return function(props: Props): TextLabel
	return create("TextLabel")({
		Name = "RoomCode",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 16, 0, 16),
		Size = UDim2.fromOffset(220, 28),
		BackgroundTransparency = 1,
		FontFace = Theme.Typography.Title,
		Text = function()
			return `ROOM: {props.Code()}`
		end,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = function()
			return props.Code() ~= ""
		end,

		CreateRaw("UIStroke")({
			Thickness = 1.5,
			Color = Color3.new(0, 0, 0),
		}),
	}) :: TextLabel
end
