--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CreateRaw = require(ReplicatedStorage.shared.Interface.CreateRaw)
local Fonts = require(ReplicatedStorage.shared.Interface.Fonts)
local Vide = require(ReplicatedStorage.Packages.Vide)

const create = Vide.create
const indexes = Vide.indexes
const source = Vide.source
const spring = Vide.spring
const effect = Vide.effect
const untrack = Vide.untrack

export type Team = "None" | "Red" | "Blue"

export type Entry = {
	UserId: number,
	Kills: number,
	Image: string,
	Team: Team,
	IsLocal: boolean,
	Leader: boolean,
}

export type Props = {
	Visible: () -> boolean,
	Entries: () -> { Entry },
	Title: () -> string,
}

const MAX_CARDS = 8
const CARD_SIZE = 0.05
const TOP = 0.155
const CROWN_IMAGE = "rbxassetid://113555755514104"
const POP_SCALE = 1.3
const POP_HOLD = 0.08
const POP_PERIOD = 0.22
const POP_DAMPING = 0.35

const BACKGROUND: { [Team]: Color3 } = {
	None = Color3.fromRGB(12, 16, 48),
	Red = Color3.fromRGB(70, 8, 12),
	Blue = Color3.fromRGB(8, 14, 70),
}

const BORDER: { [Team]: Color3 } = {
	None = Color3.fromRGB(40, 50, 110),
	Red = Color3.fromRGB(150, 20, 28),
	Blue = Color3.fromRGB(30, 50, 200),
}

const LOCAL_BORDER = Color3.fromRGB(255, 210, 60)

local function card(entry: () -> Entry, index: number): Frame
	const target = source(1)
	local lastUser = 0
	local lastKills = 0
	local token = 0
	effect(function()
		const current = entry()
		const userId, kills = current.UserId, current.Kills
		untrack(function()
			if userId == lastUser and kills > lastKills then
				token += 1
				const mine = token
				target(POP_SCALE)
				task.delay(POP_HOLD, function()
					if token == mine then
						target(1)
					end
				end)
			end
		end)
		lastUser = userId
		lastKills = kills
	end)
	const scale = spring(target, POP_PERIOD, POP_DAMPING)

	return create("Frame")({
		Name = `Card{index}`,
		Size = UDim2.fromScale(CARD_SIZE, 1),
		LayoutOrder = index,
		BackgroundColor3 = function()
			return BACKGROUND[entry().Team]
		end,

		create("UIAspectRatioConstraint")({
			AspectRatio = 1,
		}),

		CreateRaw("UIScale")({
			Scale = scale,
		}),

		create("UICorner")({
			CornerRadius = UDim.new(0.08, 0),
		}),

		CreateRaw("UIStroke")({
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = function()
				const current = entry()
				return if current.IsLocal then LOCAL_BORDER else BORDER[current.Team]
			end,
		}),

		create("ImageLabel")({
			Name = "Photo",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = function()
				return entry().Image
			end,

			create("UICorner")({
				CornerRadius = UDim.new(0.08, 0),
			}),
		}),

		create("ImageLabel")({
			Name = "Crown",
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromScale(0.06, 0.04),
			Size = UDim2.fromScale(0.32, 0.32),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Image = CROWN_IMAGE,
			Visible = function()
				return entry().Leader
			end,
		}),

		create("TextLabel")({
			Name = "Kills",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(0.96, 1),
			Size = UDim2.fromScale(0.5, 0.42),
			BackgroundTransparency = 1,
			FontFace = Fonts.FredokaOne,
			Text = function()
				return tostring(entry().Kills)
			end,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,

			CreateRaw("UIStroke")({
				Color = Color3.new(0, 0, 0),
				Thickness = 1.5,
			}),
		}),
	})
end

return function(props: Props): Frame
	const shown = function(): { Entry }
		const entries = props.Entries()
		if #entries <= MAX_CARDS then
			return entries
		end
		return table.move(entries, 1, MAX_CARDS, 1, {})
	end

	return create("Frame")({
		Name = "KillRanking",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, TOP),
		Size = UDim2.fromScale(1, 0.085),
		BackgroundTransparency = 1,
		Visible = function()
			return props.Visible() and #props.Entries() > 0
		end,

		create("TextLabel")({
			Name = "Title",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(0.12, 0.38),
			BackgroundColor3 = Color3.fromRGB(110, 90, 70),
			BackgroundTransparency = 0.1,
			FontFace = Fonts.FredokaOne,
			Text = props.Title,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			Visible = function()
				return props.Title() ~= ""
			end,

			create("UICorner")({
				CornerRadius = UDim.new(0.25, 0),
			}),
		}),

		create("Frame")({
			Name = "Cards",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,

			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0.004, 0),
			}),

			indexes(shown, function(entry, index)
				return card(entry, index)
			end),
		}),
	})
end
