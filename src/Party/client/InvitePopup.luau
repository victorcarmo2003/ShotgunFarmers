--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local CreateRaw = require(ReplicatedStorage.shared.Interface.CreateRaw)
local ScreenKit = require(StarterPlayer.StarterPlayerScripts.client.Interface.ScreenKit)

const create = Vide.create

const at = ScreenKit.at
const inside = ScreenKit.inside

const POPUP_X = 341
const POPUP_Y = 18
const POPUP_WIDTH = 440
const POPUP_HEIGHT = 128

const DECLINE_COLOR = Color3.fromHex("#C83C3C")
const BAR_BACKGROUND = Color3.fromRGB(60, 60, 60)

export type Props = {
	Visible: (() -> boolean)?,
	UserId: () -> number,
	Name: () -> string,
	Progress: (() -> number)?,
	OnAccept: (() -> ())?,
	OnDecline: (() -> ())?,
}

local function headshot(userId: number): string
	return `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
end

return function(props: Props): Frame
	const progress = function(): number
		return if props.Progress then math.clamp(props.Progress(), 0, 1) else 1
	end

	return ScreenKit.screen({
		Name = "InvitePopup",
		Visible = props.Visible,
		Children = {
			create("Frame")({
				Name = "Popup",
				Position = at(POPUP_X, POPUP_Y),
				Size = at(POPUP_WIDTH, POPUP_HEIGHT),
				BackgroundColor3 = ScreenKit.Colors.Black,
				BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,

				ScreenKit.stroke(ScreenKit.Colors.Green, 2),

				create("ImageLabel")({
					Name = "Photo",
					Position = inside(12, 12, POPUP_WIDTH, POPUP_HEIGHT),
					Size = inside(80, 80, POPUP_WIDTH, POPUP_HEIGHT),
					BackgroundColor3 = ScreenKit.Colors.Black,
					BackgroundTransparency = 0.4,
					Image = function()
						return headshot(props.UserId())
					end,

					create("UICorner")({
						CornerRadius = UDim.new(1, 0),
					}),
				}),

				ScreenKit.text({
					Name = "Name",
					Text = props.Name,
					Position = inside(104, 12, POPUP_WIDTH, POPUP_HEIGHT),
					Size = inside(324, 30, POPUP_WIDTH, POPUP_HEIGHT),
					FontSize = 28,
					BoxHeight = 30,
					Color = ScreenKit.Colors.Green,
					XAlignment = Enum.TextXAlignment.Left,
				}),

				ScreenKit.text({
					Name = "Message",
					Text = "INVITED YOU TO THEIR SQUAD",
					Position = inside(104, 42, POPUP_WIDTH, POPUP_HEIGHT),
					Size = inside(324, 20, POPUP_WIDTH, POPUP_HEIGHT),
					FontSize = 18,
					BoxHeight = 20,
					XAlignment = Enum.TextXAlignment.Left,
				}),

				ScreenKit.pressable({
					Name = "Accept",
					Position = inside(104, 68, POPUP_WIDTH, POPUP_HEIGHT),
					Size = inside(152, 36, POPUP_WIDTH, POPUP_HEIGHT),
					Color = ScreenKit.Colors.Green,
					OnActivated = function()
						if props.OnAccept then
							props.OnAccept()
						end
					end,
					Children = { ScreenKit.label("ACCEPT (Y)", 22, 36) },
				}),

				ScreenKit.pressable({
					Name = "Decline",
					Position = inside(272, 68, POPUP_WIDTH, POPUP_HEIGHT),
					Size = inside(152, 36, POPUP_WIDTH, POPUP_HEIGHT),
					Color = DECLINE_COLOR,
					OnActivated = function()
						if props.OnDecline then
							props.OnDecline()
						end
					end,
					Children = { ScreenKit.label("DECLINE (N)", 22, 36) },
				}),

				create("Frame")({
					Name = "Timer",
					Position = inside(12, 114, POPUP_WIDTH, POPUP_HEIGHT),
					Size = inside(416, 6, POPUP_WIDTH, POPUP_HEIGHT),
					BackgroundColor3 = BAR_BACKGROUND,

					create("Frame")({
						Name = "Fill",
						Size = function()
							return UDim2.fromScale(progress(), 1)
						end,
						BackgroundColor3 = ScreenKit.Colors.Green,
					}),

					CreateRaw("UIStroke")({
						Color = ScreenKit.Colors.Black,
						Thickness = 1,
					}),
				}),
			}),
		},
	})
end
