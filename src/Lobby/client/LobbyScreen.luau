const ReplicatedStorage = game:GetService "ReplicatedStorage"
const Vide = require(ReplicatedStorage.Packages.Vide)
const Theme = require(ReplicatedStorage.shared.Interface.Theme)
const CreateRaw = require(ReplicatedStorage.shared.Interface.CreateRaw)
const StarterPlayer = game:GetService "StarterPlayer"
const UISounds = require(StarterPlayer.StarterPlayerScripts.client.Interface.UISounds)

const create = Vide.create
const source = Vide.source
const spring = Vide.spring

const HOVER_SCALE = 1.2
const HOVER_SPRING_PERIOD = 0.15
const HOVER_SPRING_DAMPING = 1
const PRESS_SCALE = 0.9
const SELECTED_COLOR = Color3.fromHex "#1F9F68"
const SELECTED_TEXT_SCALE = 1.2
const COIN_IMAGE = "rbxassetid://123768928279796"
const HIDDEN_TABS: { [string]: boolean } = { Quests = true }

const PLAY_WIDTH = 0.35
const PLAY_HEIGHT = 1.2
const BUTTON_WIDTH = 0.15
const SIDE_GAP = 0.03
const GROUP_WIDTH = 1.2
const GROUP_PADDING = 0.04 / GROUP_WIDTH
const SIDE_EDGE = 0.5 - PLAY_WIDTH / 2 - SIDE_GAP
const SIDE_SIZE = UDim2.fromScale(BUTTON_WIDTH / GROUP_WIDTH, 1)

export type Props = {
	Visible: (() -> boolean)?,
	Selected: (() -> string)?,
	PlayersOnline: () -> number,
	Balance: (() -> number)?,
	OnNavigate: ((name: string) -> ())?,
	OnInvite: (() -> ())?,
}

type TopButtonProps = {
	Name: string,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number,
	BackgroundTransparency: number,
	BackgroundColor3: Color3?,
	PressedColor3: Color3?,
	Activated: (InputObject, number) -> (),
	Text: string,
	TextSize: number?,
	TextScale: number?,
	TextCentered: boolean?,
	Selected: () -> boolean,
	SelectedTextColor3: Color3?,
}

local function shown(name: string): boolean
	return not HIDDEN_TABS[name]
end

local function createTopButton(props: TopButtonProps)
	const size = props.Size or UDim2.fromScale(0.15, 1)
	const barHeight = 1 / size.Y.Scale
	const hovered = source(false)
	const pressed = source(false)
	const scale = spring(function()
		return if pressed() then PRESS_SCALE elseif hovered() then HOVER_SCALE else 1
	end, HOVER_SPRING_PERIOD, HOVER_SPRING_DAMPING)

	return create "Frame" {
		Name = props.Name,
		Size = size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
		Visible = shown(props.Name),

		create "ImageButton" {
			Name = "Button",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = props.BackgroundTransparency,

			Activated = function(input: InputObject, clicks: number)
				UISounds.Play("Click")
				props.Activated(input, clicks)
			end,

			BackgroundColor3 = function()
				const color = props.BackgroundColor3 or Color3.new(1, 1, 1)
				return if pressed() and props.PressedColor3 then props.PressedColor3 else color
			end,

			MouseEnter = function()
				hovered(true)
				UISounds.Play("Hover")
			end,

			MouseLeave = function()
				hovered(false)
				pressed(false)
			end,

			MouseButton1Down = function()
				pressed(true)
			end,

			MouseButton1Up = function()
				pressed(false)
			end,

			CreateRaw "UIScale" {
				Scale = scale,
			},

			create "TextLabel" {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, if props.TextCentered then 0.5 else barHeight / 2),
				Size = function()
					const multiplier = if props.Selected() then SELECTED_TEXT_SCALE else 1
					return UDim2.fromScale(0.9, barHeight * (props.TextScale or 0.4) * multiplier)
				end,
				RichText = true,
				Text = string.format("<b>%s</b>", props.Text),
				FontFace = Theme.Typography.Title,
				TextColor3 = function()
					return if props.Selected() then props.SelectedTextColor3 or SELECTED_COLOR else Color3.new(1, 1, 1)
				end,
				TextScaled = true,

				CreateRaw "UITextSizeConstraint" {
					MaxTextSize = function()
						const multiplier = if props.Selected() then SELECTED_TEXT_SCALE else 1
						return math.floor((props.TextSize or 40) * multiplier)
					end,
				},
			},

			create "UICorner" {
				TopLeftRadius = UDim.new(0, 0),
				TopRightRadius = UDim.new(0, 0),
				BottomLeftRadius = UDim.new(0.1, 0),
				BottomRightRadius = UDim.new(0.1, 0),
			},
		},
	}
end

return function(props: Props): Frame
	local function isSelected(name: string): () -> boolean
		return function()
			return props.Selected ~= nil and props.Selected() == name
		end
	end

	const inviteHovered = source(false)
	const invitePressed = source(false)
	const inviteScale = spring(function()
		return if invitePressed() then PRESS_SCALE elseif inviteHovered() then HOVER_SCALE else 1
	end, HOVER_SPRING_PERIOD, HOVER_SPRING_DAMPING)

	return create "Frame" {
		Name = "Conteiner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 1,
		Visible = props.Visible or false,

		create "Frame" {
			Name = "TopBar",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(1, 70 / 1080),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.3,

			create "Frame" {
				Name = "Buttons",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromScale(840 / 1920, 1),
				BackgroundTransparency = 1,

				create "UIAspectRatioConstraint" {
					AspectRatio = 840 / 70,
				},

				create "Frame" {
					Name = "Left",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(SIDE_EDGE, 0),
					Size = UDim2.fromScale(GROUP_WIDTH, 1),
					BackgroundTransparency = 1,

					createTopButton {
						Name = "Shop",
						Selected = isSelected("Shop"),
						LayoutOrder = 1,
						Size = SIDE_SIZE,
						BackgroundTransparency = 1,
						BackgroundColor3 = Color3.new(0, 0, 0),
						Text = "SHOP",
						Activated = function()
							if props.OnNavigate then
								props.OnNavigate("Shop")
							end
						end,
					},

					createTopButton {
						Name = "Ranks",
						Selected = isSelected("Ranks"),
						LayoutOrder = 0,
						Size = SIDE_SIZE,
						BackgroundTransparency = 1,
						BackgroundColor3 = Color3.new(0, 0, 0),
						Text = "RANKS",
						Activated = function()
							if props.OnNavigate then
								props.OnNavigate("Ranks")
							end
						end,
					},

					create "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Top,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(GROUP_PADDING, 0),
					},
				},

				createTopButton {
					Name = "Play",
					Selected = isSelected("Play"),
					SelectedTextColor3 = Color3.new(1, 1, 1),
					LayoutOrder = 2,
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0),
					BackgroundTransparency = 0,
					BackgroundColor3 = Color3.fromHex "#1F9F68",
					PressedColor3 = Color3.fromHex "#197f53",
					Size = UDim2.fromScale(PLAY_WIDTH, PLAY_HEIGHT),
					Text = "PLAY",
					TextSize = 50,
					TextScale = 0.65,
					TextCentered = true,
					Activated = function()
						if props.OnNavigate then
							props.OnNavigate("Play")
						end
					end,
				},

				create "Frame" {
					Name = "Right",
					AnchorPoint = Vector2.new(0, 0),
					Position = UDim2.fromScale(1 - SIDE_EDGE, 0),
					Size = UDim2.fromScale(GROUP_WIDTH, 1),
					BackgroundTransparency = 1,

					createTopButton {
						Name = "Carrer",
						Selected = isSelected("Carrer"),
						LayoutOrder = 1,
						Size = SIDE_SIZE,
						BackgroundTransparency = 1,
						BackgroundColor3 = Color3.new(0, 0, 0),
						Text = "CAREER",
						Activated = function()
							if props.OnNavigate then
								props.OnNavigate("Carrer")
							end
						end,
					},

					createTopButton {
						Name = "Customize",
						Selected = isSelected("Customize"),
						LayoutOrder = 2,
						Size = SIDE_SIZE,
						BackgroundTransparency = 1,
						BackgroundColor3 = Color3.new(0, 0, 0),
						Text = "CUSTOMIZE",
						Activated = function()
							if props.OnNavigate then
								props.OnNavigate("Customize")
							end
						end,
					},

					createTopButton {
						Name = "Quests",
						Selected = isSelected("Quests"),
						LayoutOrder = 3,
						Size = SIDE_SIZE,
						BackgroundTransparency = 1,
						BackgroundColor3 = Color3.new(0, 0, 0),
						Text = "QUESTS",
						Activated = function()
							if props.OnNavigate then
								props.OnNavigate("Quests")
							end
						end,
					},

					create "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						VerticalAlignment = Enum.VerticalAlignment.Top,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(GROUP_PADDING, 0),
					},
				},
			},

			create "Frame" {
				Name = "Wallet",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1115 / 1122, 0.5),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,

				create "UIAspectRatioConstraint" {
					AspectRatio = 119 / 45,
					DominantAxis = Enum.DominantAxis.Height,
				},

				create "TextLabel" {
					Name = "Balance",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.fromScale(81 / 119, 24 / 45),
					BackgroundTransparency = 1,
					RichText = true,
					Text = function()
						return string.format("<b>%d</b>", if props.Balance then props.Balance() else 0)
					end,
					FontFace = Theme.Typography.Title,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Right,

					CreateRaw "UITextSizeConstraint" {
						MaxTextSize = 40,
					},
				},

				create "ImageLabel" {
					Name = "Coin",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(1, 0.5),
					Size = UDim2.fromScale(32 / 119, 32 / 45),
					BackgroundTransparency = 1,
					ScaleType = Enum.ScaleType.Fit,
					Image = COIN_IMAGE,
				},
			},
		},

		create "Frame" {
			Name = "BottomBar",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(1, 70 / 1080),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.3,

			create "TextLabel" {
				Name = "Online",
				RichText = true,
				Text = function()
					return string.format("<b>ONLINE: %d</b>", props.PlayersOnline())
				end,
				FontFace = Theme.Typography.Title,
				Size = UDim2.fromScale(0.15, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(11 / 1122, 0.5),
				TextColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				TextScaled = true,

				CreateRaw "UITextSizeConstraint" {
					MaxTextSize = 40,
				},

				create "UIAspectRatioConstraint" {
					AspectRatio = (0.15 * 1920) / (0.5 * 70),
					DominantAxis = Enum.DominantAxis.Height,
				},
			},

			create "ImageButton" {
				Name = "Invite",
				Size = UDim2.fromScale(0.08, 1),
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.94, 0.5),

				Activated = function()
					UISounds.Play("Click")
					if props.OnInvite then
						props.OnInvite()
					end
				end,

				MouseEnter = function()
					inviteHovered(true)
					UISounds.Play("Hover")
				end,

				MouseLeave = function()
					inviteHovered(false)
					invitePressed(false)
				end,

				MouseButton1Down = function()
					invitePressed(true)
				end,

				MouseButton1Up = function()
					invitePressed(false)
				end,

				CreateRaw "UIScale" {
					Scale = inviteScale,
				},

				create "UIAspectRatioConstraint" {
					AspectRatio = (0.08 * 1920) / 70,
					DominantAxis = Enum.DominantAxis.Height,
				},

				create "TextLabel" {
					Name = "Invite",
					RichText = true,
					Text = string.format "<b>INVITE</b>", --props.PlayersOnline()),
					FontFace = Theme.Typography.Title,
					Size = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					TextColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 1,
					TextScaled = true,

					CreateRaw "UITextSizeConstraint" {
						MaxTextSize = 40,
					},
				},

				create "ImageLabel" {
					Size = UDim2.fromScale(0.15, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					BackgroundTransparency = 1,
					ScaleType = Enum.ScaleType.Fit,
					Image = "rbxassetid://126990058123529",
				},

				create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0.05, 0),
				},
			},
		},
	}
end
