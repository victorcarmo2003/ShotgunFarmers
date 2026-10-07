--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ScreenKit = require(StarterPlayer.StarterPlayerScripts.client.Interface.ScreenKit)

const create = Vide.create
const indexes = Vide.indexes

const at = ScreenKit.at
const inside = ScreenKit.inside

const PANEL_X = 311
const PANEL_WIDTH = 500
const LIST_X = 326
const LIST_Y = 140
const LIST_WIDTH = 470
const LIST_HEIGHT = 322

const CARD_WIDTH = 456
const CARD_HEIGHT = 64
const CARD_STEP = 72

const CARD_TRANSPARENCY = 0.5
const DISABLED_COLOR = Color3.fromRGB(90, 90, 90)
const LOBBY_COLOR = Color3.fromHex("#1F9F68")
const MATCH_COLOR = Color3.fromHex("#FF9D00")

export type Location = "Lobby" | "Match"

export type Friend = {
	UserId: number,
	Name: string,
	Location: Location,
	InSquad: boolean,
}

export type Props = {
	Visible: (() -> boolean)?,
	Friends: (() -> { Friend })?,
	Sent: (() -> { [number]: boolean })?,
	Loading: (() -> boolean)?,
	OnInvite: ((userId: number) -> ())?,
	OnClose: (() -> ())?,
}

const SAMPLE_FRIENDS: { Friend } = {
	{ UserId = 1, Name = "Builderman", Location = "Lobby", InSquad = false },
	{ UserId = 156, Name = "Farmer Joe", Location = "Match", InSquad = false },
	{ UserId = 261, Name = "Shotgun Kid", Location = "Lobby", InSquad = true },
}

local function constant<T>(value: T): () -> T
	return function()
		return value
	end
end

local function headshot(userId: number): string
	return `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
end

local function card(friend: () -> Friend, index: number, total: () -> number, props: Props): Frame
	const sent = function(): boolean
		const current = friend()
		return props.Sent ~= nil and props.Sent()[current.UserId] == true
	end

	const buttonText = function(): string
		const current = friend()
		if current.InSquad then
			return "IN SQUAD"
		elseif sent() then
			return "SENT"
		end
		return "INVITE"
	end

	const canvas = function(): number
		return math.max(total() * CARD_STEP, LIST_HEIGHT)
	end

	return create("Frame")({
		Name = `Friend{index}`,
		Position = function()
			return UDim2.fromScale(0, (index - 1) * CARD_STEP / canvas())
		end,
		Size = function()
			return UDim2.fromScale(CARD_WIDTH / LIST_WIDTH, CARD_HEIGHT / canvas())
		end,
		BackgroundColor3 = ScreenKit.Colors.Black,
		BackgroundTransparency = CARD_TRANSPARENCY,

		create("ImageLabel")({
			Name = "Photo",
			Position = inside(8, 8, CARD_WIDTH, CARD_HEIGHT),
			Size = inside(48, 48, CARD_WIDTH, CARD_HEIGHT),
			BackgroundColor3 = ScreenKit.Colors.Black,
			BackgroundTransparency = 0.4,
			Image = function()
				return headshot(friend().UserId)
			end,

			create("UICorner")({
				CornerRadius = UDim.new(1, 0),
			}),
		}),

		ScreenKit.text({
			Name = "Name",
			Text = function()
				return friend().Name
			end,
			Position = inside(66, 8, CARD_WIDTH, CARD_HEIGHT),
			Size = inside(250, 26, CARD_WIDTH, CARD_HEIGHT),
			FontSize = 24,
			BoxHeight = 26,
			XAlignment = Enum.TextXAlignment.Left,
		}),

		ScreenKit.text({
			Name = "Location",
			Text = function()
				return if friend().Location == "Match" then "IN MATCH" else "LOBBY"
			end,
			Position = inside(66, 36, CARD_WIDTH, CARD_HEIGHT),
			Size = inside(250, 20, CARD_WIDTH, CARD_HEIGHT),
			FontSize = 18,
			BoxHeight = 20,
			Color = function()
				return if friend().Location == "Match" then MATCH_COLOR else LOBBY_COLOR
			end,
			XAlignment = Enum.TextXAlignment.Left,
		}),

		ScreenKit.pressable({
			Name = "Invite",
			Position = inside(326, 14, CARD_WIDTH, CARD_HEIGHT),
			Size = inside(120, 36, CARD_WIDTH, CARD_HEIGHT),
			Color = function()
				return if buttonText() == "INVITE" then ScreenKit.Colors.Green else DISABLED_COLOR
			end,
			OnActivated = function()
				if buttonText() == "INVITE" and props.OnInvite then
					props.OnInvite(friend().UserId)
				end
			end,
			Children = { ScreenKit.label(buttonText, 22, 36) },
		}),
	})
end

return function(props: Props): Frame
	const friends = props.Friends or constant(SAMPLE_FRIENDS)
	const loading = props.Loading or constant(false)

	const total = function(): number
		return #friends()
	end

	return ScreenKit.screen({
		Name = "FriendsScreen",
		Visible = props.Visible,
		Children = {
			create("Frame")({
				Name = "Panel",
				Position = at(PANEL_X, 102),
				Size = at(PANEL_WIDTH, 427),
				BackgroundColor3 = ScreenKit.Colors.Black,
				BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,
			}),

			ScreenKit.header("FRIENDS"),

			create("ScrollingFrame")({
				Name = "List",
				Position = at(LIST_X, LIST_Y),
				Size = at(LIST_WIDTH, LIST_HEIGHT),
				BackgroundTransparency = 1,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = ScreenKit.Colors.White,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				CanvasSize = function()
					return UDim2.fromScale(0, math.max(total() * CARD_STEP / LIST_HEIGHT, 1))
				end,

				indexes(friends, function(friend, index)
					return card(friend, index, total, props)
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
						return if loading() then "LOADING..." else "NO FRIENDS IN THE GAME"
					end,
					Position = at(LIST_X, 280),
					Size = at(LIST_WIDTH, 30),
					FontSize = 26,
					BoxHeight = 30,
				}),
			}),

			ScreenKit.pressable({
				Name = "Close",
				Position = at(486, 474),
				Size = at(150, 40),
				Color = ScreenKit.Colors.Green,
				OnActivated = function()
					if props.OnClose then
						props.OnClose()
					end
				end,
				Children = { ScreenKit.label("CLOSE", 28, 40) },
			}),
		},
	})
end
