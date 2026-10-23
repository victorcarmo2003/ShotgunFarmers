--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local CreateRaw = require(ReplicatedStorage.shared.Interface.CreateRaw)
local Theme = require(ReplicatedStorage.shared.Interface.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Palette = require(StarterPlayer.StarterPlayerScripts.client.Interface.FarmPalette)
local FarmVFX = require(StarterPlayer.StarterPlayerScripts.client.Interface.FarmVFX)
local UISounds = require(StarterPlayer.StarterPlayerScripts.client.Interface.UISounds)

const create = Vide.create
const source = Vide.source
const spring = Vide.spring

const ASPECT = 520 / 300
const HOVER_SCALE = 1.08
const PRESS_SCALE = 0.92

export type Props = {
	Title: string?,
	Message: string,
	Success: boolean?,
	OnClose: () -> (),
}

local function kp(t: number, g: number): ColorSequenceKeypoint
	return ColorSequenceKeypoint.new(t, Color3.new(g, g, g))
end

const LIP = ColorSequence.new({ kp(0, 1), kp(0.6, 0.95), kp(0.78, 0.88), kp(0.79, 0.68), kp(1, 0.6) })
const PLANKS = ColorSequence.new({
	kp(0, 1),
	kp(0.322, 0.84),
	kp(0.323, 0.58),
	kp(0.332, 0.58),
	kp(0.334, 1),
	kp(0.655, 0.84),
	kp(0.656, 0.58),
	kp(0.665, 0.58),
	kp(0.667, 1),
	kp(1, 0.84),
})

local function outlinedText(props: {
	Name: string,
	Text: string,
	Font: Font,
	Position: UDim2,
	Size: UDim2,
	MaxSize: number,
	Wrapped: boolean?,
}): TextLabel
	return create("TextLabel")({
		Name = props.Name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.Position,
		Size = props.Size,
		BackgroundTransparency = 1,
		FontFace = props.Font,
		Text = props.Text,
		TextColor3 = Palette.TextWhite,
		TextScaled = true,
		TextWrapped = props.Wrapped == true,

		CreateRaw("UITextSizeConstraint")({
			MaxTextSize = props.MaxSize,
		}),
		CreateRaw("UIStroke")({
			Color = Palette.Ink,
			Thickness = 2.5,
			LineJoinMode = Enum.LineJoinMode.Round,
		}),
	}) :: TextLabel
end

local function nail(ax: number, ay: number): Frame
	return create("Frame")({
		Name = "Nail",
		AnchorPoint = Vector2.new(ax, ay),
		Position = UDim2.new(ax, if ax == 0 then 9 else -9, ay, if ay == 0 then 9 else -9),
		Size = UDim2.fromScale(0.022, 0.022),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		BackgroundColor3 = Palette.Nail,
		ZIndex = 3,

		create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
		CreateRaw("UIStroke")({ Color = Palette.Ink, Thickness = 1.5 }),
	}) :: Frame
end

return function(props: Props): Frame
	const success = props.Success == true
	const accent = if success then Palette.Leaf else Palette.Barn

	const hovered = source(false)
	const pressed = source(false)
	const buttonScale = spring(function()
		return if pressed() then PRESS_SCALE elseif hovered() then HOVER_SCALE else 1
	end, 0.15, 0.8)

	const popScale = CreateRaw("UIScale")({ Scale = 0.6 }) :: UIScale

	const frame = create("Frame")({
		Name = "ErrorPopup",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.36, 0.42),
		BackgroundColor3 = Palette.WoodDark,
		BorderSizePixel = 0,
		Active = true,

		popScale,
		create("UIAspectRatioConstraint")({ AspectRatio = ASPECT }),
		create("UICorner")({ CornerRadius = UDim.new(0.07, 0) }),
		CreateRaw("UIStroke")({
			Color = Palette.Ink,
			Thickness = 4,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		create("UIGradient")({ Rotation = 90, Color = PLANKS }),

		nail(0, 0),
		nail(1, 0),
		nail(0, 1),
		nail(1, 1),

		create("Frame")({
			Name = "Sign",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.02),
			Size = UDim2.fromScale(0.62, 0.24),
			Rotation = -3,
			BackgroundColor3 = accent,
			ZIndex = 4,

			create("UICorner")({ CornerRadius = UDim.new(0.2, 0) }),
			CreateRaw("UIStroke")({
				Color = Palette.Ink,
				Thickness = 3.5,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			create("UIGradient")({ Rotation = 90, Color = LIP }),

			outlinedText({
				Name = "Title",
				Text = string.upper(props.Title or if success then "SUCCESS!" else "OOPS!"),
				Font = Palette.Font,
				Position = UDim2.fromScale(0.5, 0.44),
				Size = UDim2.fromScale(0.9, 0.62),
				MaxSize = 44,
			}),
		}),

		outlinedText({
			Name = "Message",
			Text = props.Message,
			Font = Theme.Typography.Body,
			Position = UDim2.fromScale(0.5, 0.46),
			Size = UDim2.fromScale(0.84, 0.34),
			MaxSize = 34,
			Wrapped = true,
		}),

		create("Frame")({
			Name = "OkHolder",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.8),
			Size = UDim2.fromScale(0.36, 0.2),
			BackgroundTransparency = 1,

			create("TextButton")({
				Name = "Ok",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Palette.Leaf,
				AutoButtonColor = false,
				Text = "",
				Modal = true,

				Activated = function()
					UISounds.Play("Click")
					props.OnClose()
				end,
				MouseEnter = function()
					hovered(true)
					UISounds.Play("Hover")
				end,
				MouseLeave = function()
					hovered(false)
					pressed(false)
				end,
				MouseButton1Down = function()
					pressed(true)
				end,
				MouseButton1Up = function()
					pressed(false)
				end,

				CreateRaw("UIScale")({ Scale = buttonScale }),
				create("UICorner")({ CornerRadius = UDim.new(0.25, 0) }),
				CreateRaw("UIStroke")({
					Color = Palette.Ink,
					Thickness = 3,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				create("UIGradient")({ Rotation = 90, Color = LIP }),

				outlinedText({
					Name = "Label",
					Text = "OK",
					Font = Palette.Font,
					Position = UDim2.fromScale(0.5, 0.44),
					Size = UDim2.fromScale(0.8, 0.62),
					MaxSize = 36,
				}),
			}),
		}),
	}) :: Frame

	task.defer(function()
		TweenService:Create(popScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.wait(0.05)
		if not frame.Parent then
			return
		end
		const center = frame.AbsolutePosition + frame.AbsoluteSize / 2
		if success then
			FarmVFX.Burst(center, Palette.Leaf)
			FarmVFX.Sparkle(center, 14)
		else
			task.wait(0.15)
			for _, angle in { -4, 4, -3, 3, 0 } do
				TweenService:Create(frame, TweenInfo.new(0.05), { Rotation = angle }):Play()
				task.wait(0.05)
			end
		end
	end)

	return frame
end
