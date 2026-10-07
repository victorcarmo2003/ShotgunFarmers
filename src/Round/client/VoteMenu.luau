--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ScreenKit = require(StarterPlayer.StarterPlayerScripts.client.Interface.ScreenKit)

const create = Vide.create
const indexes = Vide.indexes

const at = ScreenKit.at
const inside = ScreenKit.inside

const CARD_WIDTH = 192
const CARD_HEIGHT = 253
const CARD_STEP = 225
const CARD_Y = 132
const CENTER_X = 561

const IDLE_COLOR = Color3.fromRGB(46, 46, 52)
const PICKED_COLOR = ScreenKit.Colors.Orange
const WINNER_COLOR = ScreenKit.Colors.Green

export type Option = {
	Name: string,
	DisplayName: string,
	Votes: number,
}

export type Props = {
	Visible: (() -> boolean)?,
	Options: () -> { Option },
	MyVote: () -> number,
	Winner: () -> number,
	Seconds: () -> number,
	OnVote: ((index: number) -> ())?,
}

local function cardX(count: number, index: number): number
	return CENTER_X - (count * CARD_STEP - (CARD_STEP - CARD_WIDTH)) / 2 + (index - 1) * CARD_STEP
end

local function card(option: () -> Option, index: number, props: Props): Frame
	return create("Frame")({
		Name = `Option{index}`,
		Position = function()
			return at(cardX(#props.Options(), index), CARD_Y)
		end,
		Size = at(CARD_WIDTH, CARD_HEIGHT),
		BackgroundTransparency = 1,

		ScreenKit.pressable({
			Name = "Card",
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(1, 1),
			Color = function()
				if props.Winner() == index then
					return WINNER_COLOR
				elseif props.MyVote() == index then
					return PICKED_COLOR
				end
				return IDLE_COLOR
			end,
			OnActivated = function()
				if props.OnVote then
					props.OnVote(index)
				end
			end,
			Children = {
				create("Frame")({
					Name = "Preview",
					Position = inside(15, 15, CARD_WIDTH, CARD_HEIGHT),
					Size = inside(162, 185, CARD_WIDTH, CARD_HEIGHT),
					BackgroundColor3 = ScreenKit.Colors.Black,
					BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,

					ScreenKit.text({
						Name = "Votes",
						Text = function()
							return tostring(option().Votes)
						end,
						Position = inside(0, 52, 162, 185),
						Size = inside(162, 80, 162, 185),
						FontSize = 72,
						BoxHeight = 80,
					}),
				}),

				create("Frame")({
					Name = "Title",
					Position = inside(0, 208, CARD_WIDTH, CARD_HEIGHT),
					Size = inside(CARD_WIDTH, 36, CARD_WIDTH, CARD_HEIGHT),
					BackgroundTransparency = 1,

					ScreenKit.label(function()
						return option().DisplayName
					end, 26, 36),
				}),
			},
		}),
	})
end

return function(props: Props): Frame
	return ScreenKit.screen({
		Name = "VoteMenu",
		Visible = props.Visible,
		Children = {
			ScreenKit.panel(),
			ScreenKit.header(function()
				if props.Winner() > 0 then
					return "WINNER"
				end
				return `VOTE  {math.max(0, math.floor(props.Seconds()))}`
			end),
			indexes(props.Options, function(option, index)
				return card(option, index, props)
			end),
		},
	})
end
