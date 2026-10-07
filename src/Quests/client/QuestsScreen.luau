--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ScreenKit = require(StarterPlayer.StarterPlayerScripts.client.Interface.ScreenKit)

const create = Vide.create
const show = Vide.show

const at = ScreenKit.at
const inside = ScreenKit.inside

const CARD_WIDTH = 391
const CARD_HEIGHT = 71
const CARD_COLUMNS = { 124, 605 }
const CARD_TOP = 130
const CARD_ROW_STEP = 85
const MAX_QUESTS = 8
const CARD_TRANSPARENCY = 0.5

const PROGRESS_SEGMENTS = 4
const PROGRESS_STEP = 76
const PROGRESS_FILLED_COLOR = Color3.fromHex("#F9B72A")
const REDEEM_COLOR = Color3.fromHex("#FFAE00")

export type Quest = {
	Id: string,
	Title: string,
	Progress: number,
	Goal: number,
	Reward: number,
	Claimable: boolean,
}

export type Props = {
	Visible: (() -> boolean)?,
	Quests: (() -> { Quest })?,
	OnRedeem: ((id: string) -> ())?,
	OnClose: (() -> ())?,
}

const DEFAULT_QUESTS: { Quest } = {
	{ Id = "Sample1", Title = "Kill 5 players", Progress = 5, Goal = 5, Reward = 200, Claimable = true },
	{ Id = "Sample2", Title = "Kill 5 players", Progress = 2, Goal = 5, Reward = 200, Claimable = false },
	{ Id = "Sample3", Title = "Kill 5 players", Progress = 2, Goal = 5, Reward = 200, Claimable = false },
	{ Id = "Sample4", Title = "Kill 5 players", Progress = 2, Goal = 5, Reward = 200, Claimable = false },
	{ Id = "Sample5", Title = "Kill 5 players", Progress = 5, Goal = 5, Reward = 200, Claimable = true },
	{ Id = "Sample6", Title = "Kill 5 players", Progress = 2, Goal = 5, Reward = 200, Claimable = false },
	{ Id = "Sample7", Title = "Kill 5 players", Progress = 2, Goal = 5, Reward = 200, Claimable = false },
	{ Id = "Sample8", Title = "Kill 5 players", Progress = 2, Goal = 5, Reward = 200, Claimable = false },
}

local function constant<T>(value: T): () -> T
	return function()
		return value
	end
end

local function card(quests: () -> { Quest }, index: number, props: Props): Frame
	const column = (index - 1) // 4 + 1
	const row = (index - 1) % 4

	const quest = function(): Quest?
		return quests()[index]
	end

	const claimable = function(): boolean
		const current = quest()
		return current ~= nil and current.Claimable
	end

	const segments: { Instance } = {}
	for segment = 1, PROGRESS_SEGMENTS do
		table.insert(
			segments,
			create("Frame")({
				Name = `Segment{segment}`,
				Position = inside(6 + PROGRESS_STEP * (segment - 1), 48, CARD_WIDTH, CARD_HEIGHT),
				Size = inside(73, 10, CARD_WIDTH, CARD_HEIGHT),
				BorderSizePixel = 0,
				BackgroundColor3 = function()
					const current = quest()
					if not current then
						return ScreenKit.Colors.White
					end
					const ratio = math.clamp(current.Progress / math.max(current.Goal, 1), 0, 1)
					return if segment <= math.floor(ratio * PROGRESS_SEGMENTS) then PROGRESS_FILLED_COLOR else ScreenKit.Colors.White
				end,
			})
		)
	end

	return create("Frame")({
		Name = `Quest{index}`,
		Position = at(CARD_COLUMNS[column], CARD_TOP + CARD_ROW_STEP * row),
		Size = at(CARD_WIDTH, CARD_HEIGHT),
		BackgroundColor3 = ScreenKit.Colors.Black,
		BackgroundTransparency = CARD_TRANSPARENCY,
		Visible = function()
			return quest() ~= nil
		end,

		show(function()
			return not claimable()
		end, function()
			return create("Frame")({
				Name = "Progress",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,

				ScreenKit.text({
					Name = "Title",
					Text = function()
						const current = quest()
						return if current then current.Title else ""
					end,
					Position = inside(6, 4, CARD_WIDTH, CARD_HEIGHT),
					Size = inside(300, 29, CARD_WIDTH, CARD_HEIGHT),
					FontSize = 29,
					BoxHeight = 29,
				}),

				segments,
			})
		end),

		show(claimable, function()
			return ScreenKit.pressable({
				Name = "Redeem",
				Position = inside(50, 18, CARD_WIDTH, CARD_HEIGHT),
				Size = inside(256, 35, CARD_WIDTH, CARD_HEIGHT),
				Color = REDEEM_COLOR,
				OnActivated = function()
					const current = quest()
					if current and props.OnRedeem then
						props.OnRedeem(current.Id)
					end
				end,
				Children = { ScreenKit.label("REDEEM", 35, 35) },
			})
		end),

		create("ImageLabel")({
			Name = "Coin",
			Position = inside(318, 9, CARD_WIDTH, CARD_HEIGHT),
			Size = inside(50, 49, CARD_WIDTH, CARD_HEIGHT),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Image = ScreenKit.Images.Coin,
		}),

		ScreenKit.text({
			Name = "Reward",
			Text = function()
				const current = quest()
				return if current then `{current.Reward}x` else ""
			end,
			Position = inside(332, 45, CARD_WIDTH, CARD_HEIGHT),
			Size = inside(48, 18, CARD_WIDTH, CARD_HEIGHT),
			FontSize = 18,
			BoxHeight = 18,
		}),
	})
end

return function(props: Props): Frame
	const quests = props.Quests or constant(DEFAULT_QUESTS)

	const cards: { Instance } = {}
	for index = 1, MAX_QUESTS do
		table.insert(cards, card(quests, index, props))
	end

	return ScreenKit.screen({
		Name = "QuestsScreen",
		Visible = props.Visible,
		Children = {
			ScreenKit.panel(),
			ScreenKit.header("QUESTS"),
			cards,
			ScreenKit.returnButton(479, props.OnClose),
		},
	})
end
