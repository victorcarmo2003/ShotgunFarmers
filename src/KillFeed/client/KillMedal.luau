--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CreateRaw = require(ReplicatedStorage.shared.Interface.CreateRaw)
local Fonts = require(ReplicatedStorage.shared.Interface.Fonts)
local MedalSettings = require(ReplicatedStorage.shared.KillFeed.MedalSettings)
local Vide = require(ReplicatedStorage.Packages.Vide)

const create = Vide.create

export type Props = {
	Text: () -> string,
	SubText: () -> string,
	Color: () -> Color3,
	Elapsed: () -> number,
}

local function alpha(elapsed: number): number
	const fadeStart = MedalSettings.Duration - MedalSettings.FadeTime
	return math.clamp((elapsed - fadeStart) / MedalSettings.FadeTime, 0, 1)
end

local function scale(elapsed: number): number
	const t = math.clamp(elapsed / MedalSettings.PopTime, 0, 1)
	const eased = 1 - (1 - t) * (1 - t)
	return MedalSettings.StartScale + (1 - MedalSettings.StartScale) * eased
end

local function label(name: string, size: number, order: number, text: () -> string, color: () -> Color3, elapsed: () -> number): TextLabel
	return create("TextLabel")({
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, size + 8),
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		FontFace = Fonts.FredokaOne,
		TextColor3 = color,
		TextTransparency = function()
			return alpha(elapsed())
		end,
		Visible = function()
			return text() ~= ""
		end,

		CreateRaw("UIStroke")({
			Thickness = 3,
			Color = Color3.fromRGB(20, 12, 8),
			Transparency = function()
				return alpha(elapsed())
			end,
		}),
	})
end

return function(props: Props): Frame
	return create("Frame")({
		Name = "KillMedal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, MedalSettings.PositionY),
		Size = UDim2.fromScale(0.5, 0.2),
		BackgroundTransparency = 1,
		Visible = function()
			return props.Elapsed() < MedalSettings.Duration
		end,

		create("UIListLayout")({
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 2),
		}),

		CreateRaw("UIScale")({
			Scale = function()
				return scale(props.Elapsed())
			end,
		}),

		label("Title", MedalSettings.TextSize, 0, props.Text, props.Color, props.Elapsed),
		label("Streak", MedalSettings.SubTextSize, 1, props.SubText, function()
			return MedalSettings.StreakColor
		end, props.Elapsed),
	})
end
