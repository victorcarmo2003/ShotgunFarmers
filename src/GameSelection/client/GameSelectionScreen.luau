--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ScreenKit = require(StarterPlayer.StarterPlayerScripts.client.Interface.ScreenKit)

const create = Vide.create

const at = ScreenKit.at
const inside = ScreenKit.inside
const label = ScreenKit.label

export type Mode = "QuickPlay" | "FFA" | "TDM" | "Practice"

export type Props = {
	Visible: (() -> boolean)?,
	OnSelectMode: ((mode: Mode) -> ())?,
	OnJoinRoom: (() -> ())?,
	OnCreateRoom: (() -> ())?,
	OnClose: (() -> ())?,
	Status: (() -> string)?,
}

const MODES: { { Mode: Mode, Label: string, X: number } } = {
	{ Mode = "QuickPlay", Label = "QUICK-PLAY", X = 124 },
	{ Mode = "FFA", Label = "FFA", X = 349 },
	{ Mode = "TDM", Label = "TDM", X = 574 },
	{ Mode = "Practice", Label = "PRACTICE", X = 799 },
}

local function modeCard(props: Props, mode: Mode, text: string, x: number): Frame
	return ScreenKit.pressable({
		Name = mode,
		Position = at(x, 132),
		Size = at(192, 253),
		OnActivated = function()
			if props.OnSelectMode then
				props.OnSelectMode(mode)
			end
		end,
		Children = {
			create("Frame")({
				Name = "Preview",
				Position = inside(15, 15, 192, 253),
				Size = inside(162, 185, 192, 253),
				BackgroundColor3 = ScreenKit.Colors.Black,
				BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,
			}),

			create("Frame")({
				Name = "Title",
				Position = inside(0, 208, 192, 253),
				Size = inside(192, 36, 192, 253),
				BackgroundTransparency = 1,

				label(text, 36, 36),
			}),
		},
	})
end

local function wideButton(name: string, text: string, y: number, onActivated: (() -> ())?): Frame
	return ScreenKit.pressable({
		Name = name,
		Position = at(466, y),
		Size = at(190, 43),
		OnActivated = onActivated,
		Children = { label(text, 36, 43) },
	})
end

return function(props: Props): Frame
	const cards: { Instance } = {}
	for _, entry in MODES do
		table.insert(cards, modeCard(props, entry.Mode, entry.Label, entry.X))
	end

	return ScreenKit.screen({
		Name = "GameSelectionScreen",
		Visible = props.Visible,
		Children = {
			ScreenKit.panel(),
			ScreenKit.header(function()
				const status = if props.Status then props.Status() else ""
				return if status ~= "" then status else "SELECTION"
			end),
			cards,
			wideButton("JoinRoom", "JOIN ROOM", 406, props.OnJoinRoom),
			wideButton("CreateRoom", "CREATE ROOM", 466, props.OnCreateRoom),
			ScreenKit.returnButton(481, props.OnClose),
		},
	})
end
