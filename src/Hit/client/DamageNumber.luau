--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CreateRaw = require(ReplicatedStorage.shared.Interface.CreateRaw)
local Fonts = require(ReplicatedStorage.shared.Interface.Fonts)
local Vide = require(ReplicatedStorage.Packages.Vide)

const create = Vide.create
const effect = Vide.effect

const NORMAL_COLOR = Color3.fromRGB(255, 255, 255)
const HEADSHOT_COLOR = Color3.fromRGB(255, 214, 64)
const KILL_COLOR = Color3.fromRGB(255, 86, 64)
const STROKE_COLOR = Color3.fromRGB(28, 20, 12)
const POP_SCALE = 1.35
const POP_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
const FADE_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

export type Props = {
	Amount: () -> number,
	Headshot: () -> boolean,
	Killed: () -> boolean,
	Pop: () -> number,
	Fading: () -> boolean,
}

return function(props: Props): Frame
	const scale = CreateRaw("UIScale")({ Scale = 1 })
	const stroke = CreateRaw("UIStroke")({ Color = STROKE_COLOR, Thickness = 2.5 })
	const label = create("TextLabel")({
		Name = "Amount",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = Fonts.FredokaOne,
		TextScaled = true,
		Text = function()
			return tostring(props.Amount())
		end,
		TextColor3 = function()
			return if props.Killed() then KILL_COLOR elseif props.Headshot() then HEADSHOT_COLOR else NORMAL_COLOR
		end,

		stroke,
	})

	local previous: number? = nil
	effect(function()
		const current = props.Pop()
		const fired = previous ~= nil and current ~= previous
		previous = current
		if not fired then
			return
		end

		scale.Scale = POP_SCALE
		TweenService:Create(scale, POP_TWEEN, { Scale = 1 }):Play()
	end)

	effect(function()
		if props.Fading() then
			TweenService:Create(label, FADE_TWEEN, { TextTransparency = 1 }):Play()
			TweenService:Create(stroke, FADE_TWEEN, { Transparency = 1 }):Play()
		end
	end)

	return create("Frame")({
		Name = "DamageNumber",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		scale,
		label,
	})
end
