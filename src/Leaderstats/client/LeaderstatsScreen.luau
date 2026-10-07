--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ScreenKit = require(StarterPlayer.StarterPlayerScripts.client.Interface.ScreenKit)

const create = Vide.create

const at = ScreenKit.at
const inside = ScreenKit.inside

const BADGE_COLOR = Color3.fromHex("#0077FF")
const RED_COLOR = Color3.fromHex("#CC0000")
const BLUE_COLOR = Color3.fromHex("#0095FF")
const LOCAL_COLOR = Color3.fromHex("#00CFAD")
const PING_GOOD_COLOR = Color3.fromHex("#00CFAD")
const PING_MEDIUM_COLOR = Color3.fromHex("#FFE100")
const PING_BAD_COLOR = Color3.fromHex("#FF0004")
const XP_FILLED_COLOR = Color3.fromHex("#F9B72A")
const DIVIDER_TRANSPARENCY = 0.85

const PING_MEDIUM = 80
const PING_BAD = 150
const PING_TEXT_WIDTH = 28

const TABLE_WIDTH = 384
const TABLE_HEIGHT = 239
const ROWS_PER_TABLE = 5
const ROW_TOP = 27
const ROW_STEP = 44
const ROW_HEIGHT = 36
const HEADER_HEIGHT = 19

const XP_SEGMENTS = 11
const XP_SEGMENT_WIDTH = 45
const XP_BAR_WIDTH = 512
const CARD_WIDTH = 580
const CARD_HEIGHT = 86

type Column = { Key: string, Label: string, X: number, Width: number }

const COLUMNS: { Column } = {
	{ Key = "Rank", Label = "#", X = 0, Width = 54 },
	{ Key = "Avatar", Label = "", X = 58, Width = 39 },
	{ Key = "Name", Label = "NAME", X = 101, Width = 82 },
	{ Key = "Score", Label = "SCORE", X = 187, Width = 41 },
	{ Key = "Ping", Label = "PING", X = 232, Width = 44 },
	{ Key = "Kills", Label = "K", X = 280, Width = 32 },
	{ Key = "Deaths", Label = "D", X = 316, Width = 32 },
	{ Key = "Assists", Label = "A", X = 352, Width = 32 },
}

export type Mode = "FFA" | "TDM"

export type Row = {
	Name: string,
	Score: number,
	Ping: number,
	Kills: number,
	Deaths: number,
	Assists: number,
	Image: string?,
	IsLocal: boolean?,
}

export type Props = {
	Visible: (() -> boolean)?,
	Mode: (() -> Mode)?,
	Players: (() -> { Row })?,
	Red: (() -> { Row })?,
	Blue: (() -> { Row })?,
	TimeLeft: (() -> number)?,
	PlayerName: (() -> string)?,
	PlayerImage: (() -> string)?,
	Level: (() -> number)?,
	Xp: (() -> number)?,
	XpMax: (() -> number)?,
}

local function sampleRow(isLocal: boolean): Row
	return { Name = "PLAYER_NAME", Score = 10, Ping = 3, Kills = 4, Deaths = 1, Assists = 5, IsLocal = isLocal }
end

const SAMPLE_ROWS: { Row } = {}
for index = 1, ROWS_PER_TABLE * 2 do
	table.insert(SAMPLE_ROWS, sampleRow(index == 1))
end

local function constant<T>(value: T): () -> T
	return function()
		return value
	end
end

local function pingColor(ping: number): Color3
	return if ping >= PING_BAD then PING_BAD_COLOR elseif ping >= PING_MEDIUM then PING_MEDIUM_COLOR else PING_GOOD_COLOR
end

local function cell(name: string, text: () -> string, column: Column, y: number, height: number, fontSize: number, color: (() -> Color3)?): Frame
	return ScreenKit.text({
		Name = name,
		Text = text,
		Position = inside(column.X, y, TABLE_WIDTH, TABLE_HEIGHT),
		Size = inside(column.Width, height, TABLE_WIDTH, TABLE_HEIGHT),
		FontSize = fontSize,
		BoxHeight = height,
		Color = color,
	})
end

local function pingBars(color: () -> Color3): Frame
	const bars: { Instance } = {}
	for index, height in { 4, 7, 10 } do
		table.insert(
			bars,
			create("Frame")({
				Name = `Bar{index}`,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale((index - 1) * 4 / 11, 1),
				Size = UDim2.fromScale(3 / 11, height / 10),
				BorderSizePixel = 0,
				BackgroundColor3 = color,
			})
		)
	end

	return create("Frame")({
		Name = "Signal",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromScale(11 / 44, 10 / ROW_HEIGHT),
		BackgroundTransparency = 1,

		bars,
	})
end

local function tableRow(rows: () -> { Row }, index: number, rankOffset: number): { Instance }
	const y = ROW_TOP + ROW_STEP * (index - 1)

	const row = function(): Row?
		return rows()[index]
	end

	local function field(getter: (Row) -> string): () -> string
		return function()
			const current = row()
			return if current then getter(current) else ""
		end
	end

	const nameColor = function(): Color3
		const current = row()
		return if current and current.IsLocal then LOCAL_COLOR else ScreenKit.Colors.White
	end

	const ping = function(): number
		const current = row()
		return if current then current.Ping else 0
	end

	const signalColor = function(): Color3
		return pingColor(ping())
	end

	const pingCell = create("Frame")({
		Name = `Row{index}Ping`,
		Position = inside(COLUMNS[5].X, y, TABLE_WIDTH, TABLE_HEIGHT),
		Size = inside(COLUMNS[5].Width, ROW_HEIGHT, TABLE_WIDTH, TABLE_HEIGHT),
		BackgroundTransparency = 1,

		ScreenKit.text({
			Name = "Value",
			Text = field(function(current)
				return `{current.Ping}ms`
			end),
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(PING_TEXT_WIDTH / COLUMNS[5].Width, 1),
			FontSize = 15,
			BoxHeight = ROW_HEIGHT,
			Color = signalColor,
			XAlignment = Enum.TextXAlignment.Right,
		}),

		pingBars(signalColor),
	})

	return {
		cell(`Row{index}Rank`, constant(tostring(rankOffset + index)), COLUMNS[1], y, ROW_HEIGHT, 16),

		create("ImageLabel")({
			Name = `Row{index}Avatar`,
			Position = inside(COLUMNS[2].X, y, TABLE_WIDTH, TABLE_HEIGHT),
			Size = inside(COLUMNS[2].Width, ROW_HEIGHT, TABLE_WIDTH, TABLE_HEIGHT),
			BackgroundColor3 = ScreenKit.Colors.White,
			BackgroundTransparency = function()
				return if row() then 0 else 1
			end,
			ScaleType = Enum.ScaleType.Crop,
			Image = function()
				const current = row()
				return if current and current.Image then current.Image else ""
			end,
		}),

		cell(`Row{index}Name`, field(function(current)
			return current.Name
		end), COLUMNS[3], y, ROW_HEIGHT, 15, nameColor),

		cell(`Row{index}Score`, field(function(current)
			return tostring(current.Score)
		end), COLUMNS[4], y, ROW_HEIGHT, 20),

		pingCell,

		cell(`Row{index}Kills`, field(function(current)
			return tostring(current.Kills)
		end), COLUMNS[6], y, ROW_HEIGHT, 20),

		cell(`Row{index}Deaths`, field(function(current)
			return tostring(current.Deaths)
		end), COLUMNS[7], y, ROW_HEIGHT, 20),

		cell(`Row{index}Assists`, field(function(current)
			return tostring(current.Assists)
		end), COLUMNS[8], y, ROW_HEIGHT, 20),
	}
end

local function scoreTable(name: string, x: number, y: () -> number, rows: () -> { Row }, rankOffset: number): Frame
	const children: { Instance } = {}

	for _, column in COLUMNS do
		if column.Label ~= "" then
			table.insert(children, cell(`Header{column.Key}`, constant(column.Label), column, 0, HEADER_HEIGHT, 16))
		end
	end

	for index = 1, ROWS_PER_TABLE do
		for _, instance in tableRow(rows, index, rankOffset) do
			table.insert(children, instance)
		end
	end

	for index = 1, ROWS_PER_TABLE - 1 do
		table.insert(
			children,
			create("Frame")({
				Name = `Divider{index}`,
				Position = inside(7, ROW_TOP + ROW_HEIGHT + 4 + ROW_STEP * (index - 1), TABLE_WIDTH, TABLE_HEIGHT),
				Size = inside(370, 2, TABLE_WIDTH, TABLE_HEIGHT),
				BorderSizePixel = 0,
				BackgroundColor3 = ScreenKit.Colors.White,
			})
		)
	end

	return create("Frame")({
		Name = name,
		Position = function()
			return at(x, y())
		end,
		Size = at(TABLE_WIDTH, TABLE_HEIGHT),
		BackgroundTransparency = 1,

		children,
	})
end

local function slice(rows: () -> { Row }, from: number, to: number): () -> { Row }
	return function()
		const all = rows()
		const result: { Row } = {}
		for index = from, math.min(to, #all) do
			table.insert(result, all[index])
		end
		return result
	end
end

local function playerCard(props: Props): { Instance }
	const playerName = props.PlayerName or constant("PLAYER_NAME")
	const level = props.Level or constant(10)
	const xp = props.Xp or constant(123)
	const xpMax = props.XpMax or constant(456)

	const segments: { Instance } = {}
	for index = 1, XP_SEGMENTS do
		table.insert(
			segments,
			create("Frame")({
				Name = `Segment{index}`,
				Position = inside((XP_BAR_WIDTH - XP_SEGMENT_WIDTH) / (XP_SEGMENTS - 1) * (index - 1), 48, CARD_WIDTH, CARD_HEIGHT),
				Size = inside(XP_SEGMENT_WIDTH, 10, CARD_WIDTH, CARD_HEIGHT),
				BorderSizePixel = 0,
				BackgroundColor3 = function()
					const filled = math.floor(math.clamp(xp() / math.max(xpMax(), 1), 0, 1) * XP_SEGMENTS)
					return if index <= filled then XP_FILLED_COLOR else ScreenKit.Colors.White
				end,
			})
		)
	end

	return {
		create("ImageLabel")({
			Name = "Avatar",
			Position = at(247, 504),
			Size = at(68, 66),
			BackgroundColor3 = ScreenKit.Colors.White,
			ScaleType = Enum.ScaleType.Crop,
			Image = props.PlayerImage or "",
		}),

		create("Frame")({
			Name = "PlayerCard",
			Position = at(327, 493),
			Size = at(CARD_WIDTH, CARD_HEIGHT),
			BackgroundTransparency = 1,

			ScreenKit.text({
				Name = "Name",
				Text = playerName,
				Position = inside(0, 0, CARD_WIDTH, CARD_HEIGHT),
				Size = inside(231, 44, CARD_WIDTH, CARD_HEIGHT),
				FontSize = 36,
				BoxHeight = 44,
			}),

			ScreenKit.text({
				Name = "Level",
				Text = function()
					return `LVL{level()}`
				end,
				Position = inside(231, 0, CARD_WIDTH, CARD_HEIGHT),
				Size = inside(117, 44, CARD_WIDTH, CARD_HEIGHT),
				FontSize = 36,
				BoxHeight = 44,
			}),

			segments,

			ScreenKit.text({
				Name = "Xp",
				Text = function()
					return `XP {xp()}/{xpMax()}`
				end,
				Position = inside((XP_BAR_WIDTH - 179) / 2, 54, CARD_WIDTH, CARD_HEIGHT),
				Size = inside(179, 32, CARD_WIDTH, CARD_HEIGHT),
				FontSize = 24,
				BoxHeight = 32,
			}),
		}),
	}
end

return function(props: Props): Frame
	const mode = props.Mode or constant("FFA" :: Mode)
	const players = props.Players or constant(SAMPLE_ROWS)
	const red = props.Red or slice(constant(SAMPLE_ROWS), 1, ROWS_PER_TABLE)
	const blue = props.Blue or slice(constant(SAMPLE_ROWS), ROWS_PER_TABLE + 1, ROWS_PER_TABLE * 2)
	const timeLeft = props.TimeLeft or constant(650)

	const isTeams = function(): boolean
		return mode() == "TDM"
	end

	const tableY = function(): number
		return if isTeams() then 214 else 196
	end

	const leftRows = function(): { Row }
		return if isTeams() then red() else slice(players, 1, ROWS_PER_TABLE)()
	end

	const rightRows = function(): { Row }
		return if isTeams() then blue() else slice(players, ROWS_PER_TABLE + 1, ROWS_PER_TABLE * 2)()
	end

	return ScreenKit.screen({
		Name = "LeaderstatsScreen",
		Visible = props.Visible,
		Children = {
			create("Frame")({
				Name = "Panel",
				Position = at(85, 49),
				Size = at(949, 555),
				BackgroundColor3 = ScreenKit.Colors.Black,
				BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,
			}),

			create("Frame")({
				Name = "Badge",
				Position = at(404, 24),
				Size = at(314, 56),
				BackgroundColor3 = BADGE_COLOR,

				ScreenKit.label("LEADERSTATS", 40, 56),
			}),

			ScreenKit.text({
				Name = "Title",
				Text = function()
					return if isTeams() then "TEAM-DEATHMATCH (TDM)" else "FREE-FOR-ALL (FFA)"
				end,
				Position = at(311, 81),
				Size = at(509, 59),
				FontSize = 48,
				BoxHeight = 59,
			}),

			create("Frame")({
				Name = "Timer",
				Position = at(913, 73),
				Size = at(104, 29),
				BackgroundTransparency = 1,

				ScreenKit.text({
					Name = "Time",
					Text = function()
						const seconds = math.max(math.floor(timeLeft()), 0)
						return string.format("%d:%02d", seconds // 60, seconds % 60)
					end,
					Position = UDim2.fromScale(0, 0),
					Size = UDim2.fromScale(79 / 104, 1),
					FontSize = 29,
					BoxHeight = 29,
				}),

				create("Frame")({
					Name = "Clock",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(1, 0.5),
					Size = UDim2.fromScale(28 / 104, 28 / 29),
					BackgroundColor3 = ScreenKit.Colors.White,

					create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
				}),
			}),

			ScreenKit.text({
				Name = "RedTitle",
				Text = function()
					return if isTeams() then "RED" else ""
				end,
				Position = at(261, 155),
				Size = at(199, 43),
				FontSize = 43,
				BoxHeight = 43,
				Color = RED_COLOR,
			}),

			ScreenKit.text({
				Name = "BlueTitle",
				Text = function()
					return if isTeams() then "BLUE" else ""
				end,
				Position = at(673, 155),
				Size = at(199, 43),
				FontSize = 43,
				BoxHeight = 43,
				Color = BLUE_COLOR,
			}),

			scoreTable("Left", 140, tableY, leftRows, 0),
			scoreTable("Right", 569, tableY, rightRows, ROWS_PER_TABLE),

			create("Frame")({
				Name = "Divider",
				Position = function()
					return at(556, tableY() - 11)
				end,
				Size = at(2, 261),
				BorderSizePixel = 0,
				BackgroundColor3 = ScreenKit.Colors.White,
				BackgroundTransparency = DIVIDER_TRANSPARENCY,
			}),

			playerCard(props),
		},
	})
end
