--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ScreenKit = require(StarterPlayer.StarterPlayerScripts.client.Interface.ScreenKit)

const create = Vide.create

const at = ScreenKit.at

const XP_SEGMENTS = 11
const XP_SEGMENT_STEP = 75.8
const XP_EMPTY_COLOR = ScreenKit.Colors.White
const XP_FILLED_COLOR = Color3.fromHex("#F9B72A")
const STAT_LABEL_COLOR = Color3.fromHex("#00C6CF")

const STAT_COLUMNS = { 142, 328, 514, 700, 886 }
const STAT_VALUE_COLUMNS = { 146, 331, 516, 701, 886 }
const STAT_ROWS = { 280, 384 }
const STAT_VALUE_OFFSET = 36

export type Stat = {
	Label: string,
	Value: number | string,
}

export type Props = {
	Visible: (() -> boolean)?,
	PlayerName: (() -> string)?,
	Level: (() -> number)?,
	Xp: (() -> number)?,
	XpMax: (() -> number)?,
	Stats: (() -> { Stat })?,
	OnClose: (() -> ())?,
}

const DEFAULT_STATS: { Stat } = {
	{ Label = "WINS", Value = 2 },
	{ Label = "KILLS", Value = 2 },
	{ Label = "ASSISTS", Value = 2 },
	{ Label = "HEADSHOTS", Value = 2 },
	{ Label = "QUESTS", Value = 2 },
	{ Label = "MATCHS", Value = 2 },
	{ Label = "DEATHS", Value = 2 },
	{ Label = "K/D", Value = "2.00" },
	{ Label = "DAMAGE", Value = 2 },
	{ Label = "LEVEL", Value = 2 },
}

local function constant<T>(value: T): () -> T
	return function()
		return value
	end
end

local function xpBar(xp: () -> number, xpMax: () -> number): { Instance }
	const segments: { Instance } = {}
	for index = 1, XP_SEGMENTS do
		table.insert(
			segments,
			create("Frame")({
				Name = `Segment{index}`,
				Position = at(146 + XP_SEGMENT_STEP * (index - 1), 191),
				Size = at(73, 10),
				BorderSizePixel = 0,
				BackgroundColor3 = function()
					const maximum = math.max(xpMax(), 1)
					const filled = math.floor(math.clamp(xp() / maximum, 0, 1) * XP_SEGMENTS)
					return if index <= filled then XP_FILLED_COLOR else XP_EMPTY_COLOR
				end,
			})
		)
	end
	return segments
end

local function statCell(stats: () -> { Stat }, index: number): { Instance }
	const row = if index <= #STAT_COLUMNS then 1 else 2
	const column = (index - 1) % #STAT_COLUMNS + 1
	const labelWidth = if column == 4 then 147 else 135

	return {
		ScreenKit.text({
			Name = `Stat{index}Label`,
			Text = function()
				const stat = stats()[index]
				return if stat then stat.Label else ""
			end,
			Position = at(STAT_COLUMNS[column], STAT_ROWS[row]),
			Size = at(labelWidth, 44),
			FontSize = 36,
			BoxHeight = 44,
			Color = STAT_LABEL_COLOR,
			XAlignment = Enum.TextXAlignment.Left,
		}),

		ScreenKit.text({
			Name = `Stat{index}Value`,
			Text = function()
				const stat = stats()[index]
				return if stat then tostring(stat.Value) else ""
			end,
			Position = at(STAT_VALUE_COLUMNS[column], STAT_ROWS[row] + STAT_VALUE_OFFSET),
			Size = at(135, 44),
			FontSize = 32,
			BoxHeight = 44,
			XAlignment = Enum.TextXAlignment.Left,
		}),
	}
end

return function(props: Props): Frame
	const playerName = props.PlayerName or constant("PLAYER_NAME")
	const level = props.Level or constant(10)
	const xp = props.Xp or constant(123)
	const xpMax = props.XpMax or constant(456)
	const stats = props.Stats or constant(DEFAULT_STATS)

	const cells: { Instance } = {}
	for index = 1, #STAT_COLUMNS * #STAT_ROWS do
		for _, instance in statCell(stats, index) do
			table.insert(cells, instance)
		end
	end

	return ScreenKit.screen({
		Name = "CareerScreen",
		Visible = props.Visible,
		Children = {
			ScreenKit.panel(),
			ScreenKit.header("CARRER"),

			ScreenKit.text({
				Name = "PlayerName",
				Text = playerName,
				Position = at(142, 138),
				Size = at(231, 44),
				FontSize = 36,
				BoxHeight = 44,
			}),

			ScreenKit.text({
				Name = "Level",
				Text = function()
					return `LVL{level()}`
				end,
				Position = at(445, 138),
				Size = at(231, 44),
				FontSize = 36,
				BoxHeight = 44,
			}),

			xpBar(xp, xpMax),

			ScreenKit.text({
				Name = "Xp",
				Text = function()
					return `XP {xp()}/{xpMax()}`
				end,
				Position = at(471, 205),
				Size = at(179, 32),
				FontSize = 24,
				BoxHeight = 32,
			}),

			cells,

			create("Frame")({
				Name = "Divider",
				Position = at(144, 367),
				Size = at(831, 3),
				BorderSizePixel = 0,
				BackgroundColor3 = ScreenKit.Colors.White,

				create("UICorner")({
					CornerRadius = UDim.new(1, 0),
				}),
			}),

			ScreenKit.returnButton(479, props.OnClose),
		},
	})
end
