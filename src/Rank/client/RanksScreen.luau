--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local RankSettings = require(ReplicatedStorage.shared.Rank.RankSettings)
local ScreenKit = require(StarterPlayer.StarterPlayerScripts.client.Interface.ScreenKit)

const create = Vide.create
const source = Vide.source
const indexes = Vide.indexes

const at = ScreenKit.at
const inside = ScreenKit.inside

type Category = RankSettings.Category
export type Entry = RankSettings.Entry
export type Boards = { [Category]: { Entry } }
export type Mine = { [Category]: number }

const CONTENT_X = 143
const CONTENT_WIDTH = 836

const TAB_Y = 134
const TAB_WIDTH = 200
const TAB_HEIGHT = 40
const TAB_GAP = 12

const COLUMNS_Y = 186
const COLUMNS_HEIGHT = 24

const LIST_Y = 214
const LIST_HEIGHT = 248

const ROW_WIDTH = 820
const ROW_HEIGHT = 44
const ROW_STEP = 50

const MINE_X = 290
const MINE_Y = 474
const MINE_WIDTH = 689
const MINE_HEIGHT = 44

const PLACE_X = 8
const PLACE_WIDTH = 64
const PHOTO_X = 80
const PHOTO_SIZE = 36
const NAME_X = 126
const NAME_WIDTH = 470
const VALUE_X = 604
const VALUE_WIDTH = 200

const ROW_TRANSPARENCY = 0.5
const TAB_IDLE_COLOR = Color3.fromRGB(45, 45, 45)
const MUTED_COLOR = Color3.fromRGB(180, 180, 180)
const COLUMN_COLOR = Color3.fromHex("#00C6CF")
const LOCAL_COLOR = Color3.fromHex("#1F9F68")
const PODIUM_COLORS = {
	Color3.fromHex("#F9B72A"),
	Color3.fromHex("#C9D1D9"),
	Color3.fromHex("#CD7F32"),
}

export type Props = {
	Visible: (() -> boolean)?,
	Boards: (() -> Boards)?,
	Mine: (() -> Mine)?,
	OnClose: (() -> ())?,
}

const SAMPLE_BOARDS: Boards = {
	Level = {
		{ UserId = 1, Name = "Builderman", Value = 42 },
		{ UserId = 156, Name = "Farmer Joe", Value = 37 },
		{ UserId = 261, Name = "Shotgun Kid", Value = 21 },
		{ UserId = 1000, Name = "Sniper Sam", Value = 9 },
	},
}

const LABELS: { [Category]: string } = {}
for _, info in RankSettings.CATEGORIES do
	LABELS[info.Id] = info.Label
end

local function constant<T>(value: T): () -> T
	return function()
		return value
	end
end

local function headshot(userId: number): string
	return if userId > 0 then `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150` else ""
end

local function format(value: number): string
	const digits = tostring(math.max(math.floor(value), 0))
	const grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (grouped:gsub("^,", ""))
end

local function tab(info: RankSettings.CategoryInfo, index: number, selected: Vide.Source<Category>): Frame
	return ScreenKit.pressable({
		Name = `Tab{info.Id}`,
		Position = at(CONTENT_X + (index - 1) * (TAB_WIDTH + TAB_GAP), TAB_Y),
		Size = at(TAB_WIDTH, TAB_HEIGHT),
		Color = function()
			return if selected() == info.Id then ScreenKit.Colors.Green else TAB_IDLE_COLOR
		end,
		OnActivated = function()
			selected(info.Id)
		end,
		Children = { ScreenKit.label(info.Label, 24, TAB_HEIGHT) },
	})
end

local function column(name: string, text: ScreenKit.Text, x: number, width: number, alignment: Enum.TextXAlignment): Frame
	return ScreenKit.text({
		Name = name,
		Text = text,
		Position = at(CONTENT_X + x, COLUMNS_Y),
		Size = at(width, COLUMNS_HEIGHT),
		FontSize = 20,
		BoxHeight = COLUMNS_HEIGHT,
		Color = COLUMN_COLOR,
		XAlignment = alignment,
	})
end

local function row(entry: () -> Entry, index: number): Frame
	const isLocal = function(): boolean
		return entry().UserId == Players.LocalPlayer.UserId
	end

	return create("Frame")({
		Name = `Row{index}`,
		LayoutOrder = index,
		Size = UDim2.new(ROW_WIDTH / CONTENT_WIDTH, 0, 0, 10000),
		BackgroundTransparency = 1,

		create("UIAspectRatioConstraint")({
			AspectRatio = ROW_WIDTH / ROW_STEP,
			AspectType = Enum.AspectType.FitWithinMaxSize,
			DominantAxis = Enum.DominantAxis.Width,
		}),

		create("Frame")({
			Name = "Card",
			Size = UDim2.fromScale(1, ROW_HEIGHT / ROW_STEP),
			BackgroundColor3 = function()
				return if isLocal() then LOCAL_COLOR else ScreenKit.Colors.Black
			end,
			BackgroundTransparency = ROW_TRANSPARENCY,
			BorderSizePixel = 0,

			ScreenKit.text({
				Name = "Place",
				Text = `#{index}`,
				Position = inside(PLACE_X, 4, ROW_WIDTH, ROW_HEIGHT),
				Size = inside(PLACE_WIDTH, 36, ROW_WIDTH, ROW_HEIGHT),
				FontSize = 26,
				BoxHeight = 36,
				Color = PODIUM_COLORS[index] or ScreenKit.Colors.White,
			}),

			create("ImageLabel")({
				Name = "Photo",
				Position = inside(PHOTO_X, 4, ROW_WIDTH, ROW_HEIGHT),
				Size = inside(PHOTO_SIZE, PHOTO_SIZE, ROW_WIDTH, ROW_HEIGHT),
				BackgroundColor3 = ScreenKit.Colors.Black,
				BackgroundTransparency = 0.4,
				Image = function()
					return headshot(entry().UserId)
				end,

				create("UICorner")({
					CornerRadius = UDim.new(1, 0),
				}),
			}),

			ScreenKit.text({
				Name = "Name",
				Text = function()
					return entry().Name
				end,
				Position = inside(NAME_X, 6, ROW_WIDTH, ROW_HEIGHT),
				Size = inside(NAME_WIDTH, 32, ROW_WIDTH, ROW_HEIGHT),
				FontSize = 24,
				BoxHeight = 32,
				XAlignment = Enum.TextXAlignment.Left,
			}),

			ScreenKit.text({
				Name = "Value",
				Text = function()
					return format(entry().Value)
				end,
				Position = inside(VALUE_X, 6, ROW_WIDTH, ROW_HEIGHT),
				Size = inside(VALUE_WIDTH, 32, ROW_WIDTH, ROW_HEIGHT),
				FontSize = 24,
				BoxHeight = 32,
				XAlignment = Enum.TextXAlignment.Right,
			}),
		}),
	})
end

return function(props: Props): Frame
	const boards = props.Boards or constant(SAMPLE_BOARDS)
	const mine = props.Mine or constant({} :: Mine)
	const selected = source(RankSettings.IDS[1]) :: Vide.Source<Category>

	const entries = function(): { Entry }
		return boards()[selected()] or {}
	end
	const total = function(): number
		return #entries()
	end
	const place = function(): number?
		const userId = Players.LocalPlayer.UserId
		for index, entry in entries() do
			if entry.UserId == userId then
				return index
			end
		end
		return nil
	end

	const tabs: { Instance } = {}
	for index, info in RankSettings.CATEGORIES do
		table.insert(tabs, tab(info, index, selected))
	end

	return ScreenKit.screen({
		Name = "RanksScreen",
		Visible = props.Visible,
		Children = {
			ScreenKit.panel(),
			ScreenKit.header("RANKS"),

			tabs,

			column("PlaceColumn", "#", PLACE_X, PLACE_WIDTH, Enum.TextXAlignment.Center),
			column("NameColumn", "PLAYER", NAME_X, NAME_WIDTH, Enum.TextXAlignment.Left),
			column("ValueColumn", function()
				return LABELS[selected()]
			end, VALUE_X, VALUE_WIDTH, Enum.TextXAlignment.Right),

			create("ScrollingFrame")({
				Name = "List",
				Position = at(CONTENT_X, LIST_Y),
				Size = at(CONTENT_WIDTH, LIST_HEIGHT),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = ScreenKit.Colors.White,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasPosition = function()
					selected()
					return Vector2.zero
				end,

				create("UIListLayout")({
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),

				indexes(entries, function(entry, index)
					return row(entry, index)
				end),
			}),

			create("Frame")({
				Name = "EmptyState",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Visible = function()
					return total() == 0
				end,

				ScreenKit.text({
					Name = "Empty",
					Text = function()
						return if boards()[selected()] == nil then "LOADING..." else "NO RANKED PLAYERS YET"
					end,
					Position = at(CONTENT_X, 320),
					Size = at(CONTENT_WIDTH, 30),
					FontSize = 26,
					BoxHeight = 30,
					Color = MUTED_COLOR,
				}),
			}),

			create("Frame")({
				Name = "Mine",
				Position = at(MINE_X, MINE_Y),
				Size = at(MINE_WIDTH, MINE_HEIGHT),
				BackgroundColor3 = LOCAL_COLOR,
				BackgroundTransparency = 0.2,
				BorderSizePixel = 0,

				ScreenKit.text({
					Name = "Place",
					Text = function()
						const current = place()
						return if current then `YOUR RANK  #{current}` else `YOUR RANK  NOT IN TOP {RankSettings.TOP_SIZE}`
					end,
					Position = inside(14, 6, MINE_WIDTH, MINE_HEIGHT),
					Size = inside(420, 32, MINE_WIDTH, MINE_HEIGHT),
					FontSize = 24,
					BoxHeight = 32,
					XAlignment = Enum.TextXAlignment.Left,
				}),

				ScreenKit.text({
					Name = "Value",
					Text = function()
						const value = mine()[selected()]
						return `{LABELS[selected()]}  {if value then format(value) else "-"}`
					end,
					Position = inside(MINE_WIDTH - 314, 6, MINE_WIDTH, MINE_HEIGHT),
					Size = inside(300, 32, MINE_WIDTH, MINE_HEIGHT),
					FontSize = 24,
					BoxHeight = 32,
					XAlignment = Enum.TextXAlignment.Right,
				}),
			}),

			ScreenKit.returnButton(479, props.OnClose),
		},
	})
end
