--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CreateRaw = require(ReplicatedStorage.shared.Interface.CreateRaw)
local Fonts = require(ReplicatedStorage.shared.Interface.Fonts)
local Vide = require(ReplicatedStorage.Packages.Vide)

const create = Vide.create

export type Team = "None" | "Red" | "Blue"

export type Props = {
	Visible: () -> boolean,
	Red: () -> number,
	Blue: () -> number,
	LocalTeam: () -> Team,
}

const RED = Color3.fromHex("#C62F2F")
const BLUE = Color3.fromHex("#2A7BD1")
const BOX_WIDTH = 0.07
const BOX_HEIGHT = 0.06
const OFFSET = 0.13
const TOP = 0.1

local function scoreText(value: number): string
	return if value == math.floor(value) then tostring(value) else string.format("%.1f", value)
end

local function box(name: string, team: Team, x: number, color: Color3, value: () -> number, localTeam: () -> Team): Frame
	return create("Frame")({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, TOP),
		Size = UDim2.fromScale(BOX_WIDTH, BOX_HEIGHT),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.15,

		CreateRaw("UIStroke")({
			Color = Color3.new(1, 1, 1),
			Thickness = function()
				return if localTeam() == team then 3 else 0
			end,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),

		create("TextLabel")({
			Name = "Score",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = Fonts.FredokaOne,
			Text = function()
				return scoreText(value())
			end,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
		}),
	})
end

return function(props: Props): Frame
	return create("Frame")({
		Name = "TeamScore",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = props.Visible,

		box("Red", "Red", 0.5 - OFFSET, RED, props.Red, props.LocalTeam),
		box("Blue", "Blue", 0.5 + OFFSET, BLUE, props.Blue, props.LocalTeam),
	})
end
