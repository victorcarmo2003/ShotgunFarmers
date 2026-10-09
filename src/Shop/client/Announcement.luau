--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ScreenKit = require(StarterPlayer.StarterPlayerScripts.client.Interface.ScreenKit)

const create = Vide.create

export type Props = {
	Message: () -> string,
	Alpha: () -> number,
}

const WIDTH = 520
const HEIGHT = 46

return function(props: Props): Frame
	return ScreenKit.screen({
		Name = "Announcement",
		Visible = function()
			return props.Alpha() > 0 and props.Message() ~= ""
		end,
		Children = {
			create("CanvasGroup")({
				Name = "Banner",
				Position = ScreenKit.at((ScreenKit.REF_WIDTH - WIDTH) / 2, 110),
				Size = ScreenKit.at(WIDTH, HEIGHT),
				BackgroundColor3 = ScreenKit.Colors.Green,
				GroupTransparency = function()
					return 1 - props.Alpha()
				end,

				ScreenKit.label(props.Message, 28, HEIGHT),
			}),
		},
	})
end
