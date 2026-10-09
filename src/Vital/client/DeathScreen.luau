--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ScreenKit = require(StarterPlayer.StarterPlayerScripts.client.Interface.ScreenKit)

const create = Vide.create

const at = ScreenKit.at
const inside = ScreenKit.inside

export type Info = {
	Killer: string,
	Gun: string,
	Headshot: boolean,
}

export type Props = {
	Visible: () -> boolean,
	Info: () -> Info,
	Remaining: () -> number,
}

const BAR_X = 361
const BAR_Y = 430
const BAR_WIDTH = 400
const BAR_HEIGHT = 110
const RED = Color3.fromHex("#C62F2F")

return function(props: Props): Frame
	const title = function(): string
		const info = props.Info()
		if info.Killer == "" then
			return "YOU DIED"
		end
		return `ELIMINATED BY {string.upper(info.Killer)}`
	end

	const detail = function(): string
		const info = props.Info()
		if info.Gun == "" then
			return ""
		end
		return if info.Headshot then `{string.upper(info.Gun)}  -  HEADSHOT` else string.upper(info.Gun)
	end

	return ScreenKit.screen({
		Name = "DeathScreen",
		Visible = props.Visible,
		Children = {
			create("Frame")({
				Name = "Vignette",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = RED,
				BackgroundTransparency = 0.85,
			}),

			create("Frame")({
				Name = "Bar",
				Position = at(BAR_X, BAR_Y),
				Size = at(BAR_WIDTH, BAR_HEIGHT),
				BackgroundColor3 = ScreenKit.Colors.Black,
				BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,

				create("Frame")({
					Name = "Header",
					Size = inside(BAR_WIDTH, 40, BAR_WIDTH, BAR_HEIGHT),
					BackgroundColor3 = RED,

					ScreenKit.label(title, 28, 40),
				}),

				ScreenKit.text({
					Name = "Gun",
					Text = detail,
					Position = inside(0, 44, BAR_WIDTH, BAR_HEIGHT),
					Size = inside(BAR_WIDTH, 28, BAR_WIDTH, BAR_HEIGHT),
					FontSize = 22,
					BoxHeight = 28,
					Color = Color3.fromRGB(220, 220, 220),
				}),

				ScreenKit.text({
					Name = "Respawn",
					Text = function()
						const remaining = math.max(0, math.ceil(props.Remaining()))
						return if remaining > 0 then `RESPAWNING IN {remaining}` else "RESPAWNING..."
					end,
					Position = inside(0, 74, BAR_WIDTH, BAR_HEIGHT),
					Size = inside(BAR_WIDTH, 30, BAR_WIDTH, BAR_HEIGHT),
					FontSize = 26,
					BoxHeight = 30,
					Color = ScreenKit.Colors.Orange,
				}),
			}),
		},
	})
end
