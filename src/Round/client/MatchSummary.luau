--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ScreenKit = require(StarterPlayer.StarterPlayerScripts.client.Interface.ScreenKit)

const create = Vide.create
const spring = Vide.spring

const at = ScreenKit.at
const inside = ScreenKit.inside

export type Outcome = "Victory" | "Defeat" | "Draw"

export type Summary = {
	Outcome: Outcome,
	Placement: number,
	Players: number,
	Kills: number,
	Deaths: number,
	Assists: number,
	Score: number,
	XpGained: number,
	GemsGained: number,
	Level: number,
	LevelsGained: number,
	Xp: number,
	XpMax: number,
	Counted: boolean,
}

export type Props = {
	Visible: () -> boolean,
	Summary: () -> Summary,
	OnClose: (() -> ())?,
}

const PANEL_X = 286
const PANEL_Y = 96
const PANEL_WIDTH = 550
const PANEL_HEIGHT = 440

const OUTCOME_TEXT: { [Outcome]: string } = {
	Victory = "VICTORY",
	Defeat = "DEFEAT",
	Draw = "DRAW",
}

const OUTCOME_ICON: { [Outcome]: string } = {
	Victory = "rbxassetid://105467907115908",
	Defeat = "rbxassetid://76382981380066",
	Draw = "",
}

const OUTCOME_COLOR: { [Outcome]: Color3 } = {
	Victory = ScreenKit.Colors.Green,
	Defeat = Color3.fromHex("#C62F2F"),
	Draw = Color3.fromHex("#5A5A5A"),
}

local function ordinal(value: number): string
	const lastTwo = value % 100
	if lastTwo >= 11 and lastTwo <= 13 then
		return `{value}TH`
	end
	const last = value % 10
	return if last == 1 then `{value}ST` elseif last == 2 then `{value}ND` elseif last == 3 then `{value}RD` else `{value}TH`
end

local function scoreText(score: number): string
	return if score == math.floor(score) then tostring(score) else string.format("%.1f", score)
end

local function spot(x: number, y: number): UDim2
	return inside(x, y, PANEL_WIDTH, PANEL_HEIGHT)
end

local function statBlock(name: string, label: string, x: number, value: () -> string): Frame
	return create("Frame")({
		Name = name,
		Position = spot(x, 168),
		Size = spot(120, 74),
		BackgroundColor3 = ScreenKit.Colors.Black,
		BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,

		ScreenKit.text({
			Name = "Value",
			Text = value,
			Position = inside(0, 6, 120, 74),
			Size = inside(120, 40, 120, 74),
			FontSize = 34,
			BoxHeight = 40,
		}),

		ScreenKit.text({
			Name = "Label",
			Text = label,
			Position = inside(0, 46, 120, 74),
			Size = inside(120, 22, 120, 74),
			FontSize = 18,
			BoxHeight = 22,
			Color = Color3.fromRGB(200, 200, 200),
		}),
	})
end

return function(props: Props): Frame
	const summary = props.Summary

	const reveal = spring(function()
		return if props.Visible() then 1 else 0
	end, 0.25, 0.8)

	const xpFraction = function(): number
		const data = summary()
		return if data.XpMax > 0 then math.clamp(data.Xp / data.XpMax, 0, 1) else 0
	end

	return ScreenKit.screen({
		Name = "MatchSummary",
		Visible = props.Visible,
		Children = {
			create("TextButton")({
				Name = "Backdrop",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = ScreenKit.Colors.Black,
				BackgroundTransparency = function()
					return 1 - 0.45 * reveal()
				end,
				Text = "",
				AutoButtonColor = false,
				Activated = function()
					if props.OnClose then
						props.OnClose()
					end
				end,
			}),

			create("Frame")({
				Name = "Panel",
				Position = function()
					return at(PANEL_X, PANEL_Y + (1 - reveal()) * 40)
				end,
				Size = at(PANEL_WIDTH, PANEL_HEIGHT),
				BackgroundColor3 = ScreenKit.Colors.Black,
				BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,

				create("Frame")({
					Name = "Banner",
					Position = spot(0, 0),
					Size = spot(PANEL_WIDTH, 96),
					BackgroundColor3 = function()
						return OUTCOME_COLOR[summary().Outcome]
					end,

					ScreenKit.label(function()
						return OUTCOME_TEXT[summary().Outcome]
					end, 64, 96),

					create("ImageLabel")({
						Name = "IconLeft",
						Position = inside(30, 14, PANEL_WIDTH, 96),
						Size = inside(68, 68, PANEL_WIDTH, 96),
						BackgroundTransparency = 1,
						ScaleType = Enum.ScaleType.Fit,
						Image = function()
							return OUTCOME_ICON[summary().Outcome]
						end,
					}),

					create("ImageLabel")({
						Name = "IconRight",
						Position = inside(PANEL_WIDTH - 98, 14, PANEL_WIDTH, 96),
						Size = inside(68, 68, PANEL_WIDTH, 96),
						BackgroundTransparency = 1,
						ScaleType = Enum.ScaleType.Fit,
						Image = function()
							return OUTCOME_ICON[summary().Outcome]
						end,
					}),
				}),

				ScreenKit.text({
					Name = "Placement",
					Text = function()
						const data = summary()
						if data.Placement <= 0 then
							return ""
						end
						return `{ordinal(data.Placement)} OF {data.Players}`
					end,
					Position = spot(0, 112),
					Size = spot(PANEL_WIDTH, 40),
					FontSize = 32,
					BoxHeight = 40,
				}),

				statBlock("Kills", "KILLS", 20, function()
					return tostring(summary().Kills)
				end),
				statBlock("Deaths", "DEATHS", 152, function()
					return tostring(summary().Deaths)
				end),
				statBlock("Assists", "ASSISTS", 284, function()
					return tostring(summary().Assists)
				end),
				statBlock("Score", "SCORE", 416, function()
					return scoreText(summary().Score)
				end),

				create("Frame")({
					Name = "Rewards",
					Position = spot(20, 260),
					Size = spot(510, 56),
					BackgroundTransparency = 1,
					Visible = function()
						return summary().Counted
					end,

					ScreenKit.text({
						Name = "Xp",
						Text = function()
							return `+{summary().XpGained} XP`
						end,
						Position = inside(0, 0, 510, 56),
						Size = inside(240, 56, 510, 56),
						FontSize = 36,
						BoxHeight = 56,
						Color = ScreenKit.Colors.Orange,
					}),

					create("ImageLabel")({
						Name = "CoinIcon",
						Position = inside(290, 8, 510, 56),
						Size = inside(40, 40, 510, 56),
						BackgroundTransparency = 1,
						ScaleType = Enum.ScaleType.Fit,
						Image = ScreenKit.Images.Coin,
					}),

					ScreenKit.text({
						Name = "Gems",
						Text = function()
							return `+{summary().GemsGained}`
						end,
						Position = inside(338, 0, 510, 56),
						Size = inside(172, 56, 510, 56),
						FontSize = 36,
						BoxHeight = 56,
						XAlignment = Enum.TextXAlignment.Left,
					}),
				}),

				create("Frame")({
					Name = "NoRewards",
					Position = spot(20, 260),
					Size = spot(510, 56),
					BackgroundTransparency = 1,
					Visible = function()
						return not summary().Counted
					end,

					ScreenKit.text({
						Name = "Label",
						Text = "PRACTICE - NO REWARDS",
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 1),
						FontSize = 28,
						BoxHeight = 56,
						Color = Color3.fromRGB(200, 200, 200),
					}),
				}),

				create("Frame")({
					Name = "Level",
					Position = spot(20, 332),
					Size = spot(510, 44),
					BackgroundColor3 = ScreenKit.Colors.Black,
					BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,
					ClipsDescendants = true,

					create("Frame")({
						Name = "Fill",
						Size = function()
							return UDim2.fromScale(xpFraction(), 1)
						end,
						BackgroundColor3 = ScreenKit.Colors.Green,
					}),

					ScreenKit.label(function()
						const data = summary()
						const levelUp = if data.LevelsGained > 0 then "LEVEL UP!  " else ""
						return `{levelUp}LEVEL {data.Level}  {math.floor(data.Xp)}/{math.floor(data.XpMax)}`
					end, 26, 44),
				}),

				ScreenKit.pressable({
					Name = "Continue",
					Position = spot(180, 388),
					Size = spot(190, 40),
					OnActivated = props.OnClose,
					Children = { ScreenKit.label("CONTINUE", 28, 40) },
				}),
			}),
		},
	})
end
