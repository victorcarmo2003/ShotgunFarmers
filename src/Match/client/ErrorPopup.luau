--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CreateRaw = require(ReplicatedStorage.shared.Interface.CreateRaw)
local Theme = require(ReplicatedStorage.shared.Interface.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

const create = Vide.create

export type Props = {
	Title: string?,
	Message: string,
	OnClose: () -> (),
}

return function(props: Props): Frame
	return create("Frame")({
		Name = "ErrorPopup",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.3, 0.3),
		BackgroundColor3 = Theme.Colors.Surface,
		BorderSizePixel = 0,

		create("UICorner")({
			CornerRadius = Theme.Spacing.CornerRadius,
		}),

		CreateRaw("UIStroke")({
			Color = Color3.fromRGB(200, 60, 60),
			Thickness = 2,
		}),

		create("TextLabel")({
			Name = "Title",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.06),
			Size = UDim2.fromScale(0.9, 0.2),
			BackgroundTransparency = 1,
			FontFace = Theme.Typography.Title,
			Text = props.Title or "Erro",
			TextColor3 = Color3.fromRGB(235, 90, 90),
			TextScaled = true,

			CreateRaw("UITextSizeConstraint")({
				MaxTextSize = Theme.Typography.TitleSize,
			}),
		}),

		create("TextLabel")({
			Name = "Message",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.3),
			Size = UDim2.fromScale(0.86, 0.4),
			BackgroundTransparency = 1,
			FontFace = Theme.Typography.Body,
			Text = props.Message,
			TextColor3 = Theme.Colors.Text,
			TextWrapped = true,
			TextScaled = true,

			CreateRaw("UITextSizeConstraint")({
				MaxTextSize = Theme.Typography.BodySize,
			}),
		}),

		create("TextButton")({
			Name = "Ok",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.92),
			Size = UDim2.fromScale(0.35, 0.18),
			BackgroundColor3 = Color3.fromHex("#1F9F68"),
			BorderSizePixel = 0,
			FontFace = Theme.Typography.Title,
			Text = "OK",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			Modal = true,

			Activated = function()
				props.OnClose()
			end,

			create("UICorner")({
				CornerRadius = Theme.Spacing.CornerRadius,
			}),

			CreateRaw("UITextSizeConstraint")({
				MaxTextSize = Theme.Typography.BodySize,
			}),
		}),
	})
end
