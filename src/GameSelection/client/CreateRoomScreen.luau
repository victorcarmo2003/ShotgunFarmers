--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Maps = require(ReplicatedStorage.shared.Match.Maps)
local Vide = require(ReplicatedStorage.Packages.Vide)
local ScreenKit = require(StarterPlayer.StarterPlayerScripts.client.Interface.ScreenKit)

const source = Vide.source

const at = ScreenKit.at

export type RoomMode = "FFA" | "TDM" | "Chicken"

export type Props = {
	Visible: (() -> boolean)?,
	OnClose: (() -> ())?,
	OnCreate: ((mode: RoomMode, mapName: string, private: boolean) -> ())?,
	Status: (() -> string)?,
}

const MODES: { { Mode: RoomMode, Label: string } } = {
	{ Mode = "FFA", Label = "FFA" },
	{ Mode = "TDM", Label = "TDM" },
	{ Mode = "Chicken", Label = "CHICKEN" },
}

const COLUMN_X = { 150, 345, 540, 735 }
const BUTTON_WIDTH = 180
const BUTTON_HEIGHT = 43
const RANDOM_MAP = ""

local function roomMaps(): { string }
	const names: { string } = {}
	for name, map in Maps do
		for _, entry in MODES do
			if table.find(map.Modes, entry.Mode) then
				table.insert(names, name)
				break
			end
		end
	end
	table.sort(names)
	return names
end

local function colorFor(selected: () -> boolean): () -> Color3
	return function()
		return if selected() then ScreenKit.Colors.Orange else ScreenKit.Colors.Green
	end
end

local function option(name: string, text: string, x: number, y: number, selected: () -> boolean, onPick: () -> ()): Frame
	return ScreenKit.pressable({
		Name = name,
		Position = at(x, y),
		Size = at(BUTTON_WIDTH, BUTTON_HEIGHT),
		Color = colorFor(selected),
		OnActivated = onPick,
		Children = { ScreenKit.label(text, 30, BUTTON_HEIGHT) },
	})
end

local function section(text: string, y: number): Frame
	return ScreenKit.text({
		Name = `{text}Title`,
		Text = text,
		Position = at(COLUMN_X[1], y),
		Size = at(400, 26),
		FontSize = 24,
		BoxHeight = 26,
		XAlignment = Enum.TextXAlignment.Left,
	})
end

return function(props: Props): Frame
	const mode = source("FFA" :: RoomMode)
	const mapName = source(RANDOM_MAP)
	const private = source(false)

	const modeButtons: { Instance } = {}
	for index, entry in MODES do
		table.insert(
			modeButtons,
			option(`Mode{entry.Mode}`, entry.Label, COLUMN_X[index], 172, function()
				return mode() == entry.Mode
			end, function()
				mode(entry.Mode)
				const current = Maps[mapName()]
				if current and not table.find(current.Modes, entry.Mode) then
					mapName(RANDOM_MAP)
				end
			end)
		)
	end

	const mapButtons: { Instance } = {
		option("MapRandom", "RANDOM", COLUMN_X[1], 262, function()
			return mapName() == RANDOM_MAP
		end, function()
			mapName(RANDOM_MAP)
		end),
	}
	for index, name in roomMaps() do
		const column = COLUMN_X[index + 1]
		if not column then
			break
		end

		const map = Maps[name]
		const button = option(`Map{name}`, string.upper(map.DisplayName), column, 262, function()
			return mapName() == name
		end, function()
			if table.find(map.Modes, mode()) then
				mapName(name)
			end
		end)
		Vide.effect(function()
			button.Visible = table.find(map.Modes, mode()) ~= nil
		end)
		table.insert(mapButtons, button)
	end

	return ScreenKit.screen({
		Name = "CreateRoomScreen",
		Visible = props.Visible,
		Children = {
			ScreenKit.panel(),
			ScreenKit.header(function()
				const status = if props.Status then props.Status() else ""
				return if status ~= "" then status else "CREATE ROOM"
			end),

			section("MODE", 140),
			modeButtons,

			section("MAP", 230),
			mapButtons,

			section("ACCESS", 320),
			option("Public", "PUBLIC", COLUMN_X[1], 352, function()
				return not private()
			end, function()
				private(false)
			end),
			option("Private", "PRIVATE", COLUMN_X[2], 352, function()
				return private()
			end, function()
				private(true)
			end),

			ScreenKit.pressable({
				Name = "Create",
				Position = at(466, 446),
				Size = at(190, 43),
				Color = ScreenKit.Colors.Orange,
				OnActivated = function()
					if props.OnCreate then
						props.OnCreate(mode(), mapName(), private())
					end
				end,
				Children = { ScreenKit.label("CREATE", 36, 43) },
			}),

			ScreenKit.returnButton(481, props.OnClose),
		},
	})
end
