--!strict
local Fonts = require(script.Parent.Fonts)

return {
	Colors = {
		Background = Color3.fromRGB(24, 24, 28),
		Surface = Color3.fromRGB(32, 32, 36),
		Primary = Color3.fromRGB(255, 255, 255),
		Accent = Color3.fromRGB(255, 255, 255),
		Text = Color3.fromRGB(235, 235, 240),
		TextMuted = Color3.fromRGB(180, 180, 185),
	},

	Typography = {
		Title = Enum.Font:FromName("Comic Neue Angular") :: any,
		Body = Fonts.FredokaOne,
		TitleSize = 48,
		BodySize = 24,
	} :: {Title: Font, Body : Font, TitleSize: number, BodySize: number},

	Spacing = {
		ScreenPadding = UDim.new(0.03, 0),
		Gap = UDim.new(0.02, 0),
		CornerRadius = UDim.new(0, 8),
	},
}
