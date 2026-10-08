--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local GameModes = require(ReplicatedStorage.shared.Match.GameModes)
local Maps = require(ReplicatedStorage.shared.Match.Maps)
local Theme = require(ReplicatedStorage.shared.Interface.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)
local ScreenKit = require(StarterPlayer.StarterPlayerScripts.client.Interface.ScreenKit)

const create = Vide.create
const indexes = Vide.indexes

const at = ScreenKit.at
const inside = ScreenKit.inside

export type Room = { Key: string, Map: string, Mode: string, Players: number, MaxPlayers: number }

export type Props = {
	Visible: (() -> boolean)?,
	OnClose: (() -> ())?,
	Rooms: (() -> { Room })?,
	Loading: (() -> boolean)?,
	OnRefresh: (() -> ())?,
	OnJoinCode: ((code: string) -> ())?,
	OnJoinRoom: ((key: string) -> ())?,
	Status: (() -> string)?,
}

const LIST_X = 130
const LIST_Y = 200
const LIST_WIDTH = 862
const LIST_HEIGHT = 230
const ROW_HEIGHT = 46
const ROW_STEP = 52
const CODE_LENGTH = 5

const SAMPLE_ROOMS: { Room } = {
	{ Key = "a", Map = "HappyFarm", Mode = "FFA", Players = 6, MaxPlayers = 10 },
	{ Key = "b", Map = "WildWest", Mode = "TDM", Players = 3, MaxPlayers = 10 },
}

local function describe(room: Room): string
	const map = Maps[room.Map]
	const mode = GameModes.Modes[room.Mode]
	const mapText = if map then map.DisplayName else room.Map
	const modeText = if mode then mode.DisplayName else room.Mode
	return string.upper(`{mapText}  -  {modeText}  -  {room.Players}/{room.MaxPlayers}`)
end

local function row(room: () -> Room, index: number, props: Props): Frame
	return create("Frame")({
		Name = `Room{index}`,
		Position = UDim2.fromScale(0, (index - 1) * ROW_STEP / LIST_HEIGHT),
		Size = UDim2.new(1, -12, ROW_HEIGHT / LIST_HEIGHT, 0),
		BackgroundColor3 = ScreenKit.Colors.Black,
		BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,

		ScreenKit.text({
			Name = "Info",
			Text = function()
				return describe(room())
			end,
			Position = inside(16, 0, LIST_WIDTH, ROW_HEIGHT),
			Size = inside(640, ROW_HEIGHT, LIST_WIDTH, ROW_HEIGHT),
			FontSize = 24,
			BoxHeight = ROW_HEIGHT,
			XAlignment = Enum.TextXAlignment.Left,
		}),

		ScreenKit.pressable({
			Name = "Join",
			Position = inside(700, 4, LIST_WIDTH, ROW_HEIGHT),
			Size = inside(140, 38, LIST_WIDTH, ROW_HEIGHT),
			OnActivated = function()
				if props.OnJoinRoom then
					props.OnJoinRoom(room().Key)
				end
			end,
			Children = { ScreenKit.label("JOIN", 26, 38) },
		}),
	})
end

return function(props: Props): Frame
	const rooms = props.Rooms or function(): { Room }
		return SAMPLE_ROOMS
	end
	const loading = props.Loading or function(): boolean
		return false
	end

	const total = function(): number
		return #rooms()
	end

	const codeBox = create("TextBox")({
		Name = "Input",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = ScreenKit.Colors.Black,
		BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,
		ClearTextOnFocus = false,
		FontFace = Theme.Typography.Title,
		PlaceholderText = "ROOM CODE",
		PlaceholderColor3 = Color3.fromRGB(170, 170, 170),
		Text = "",
		TextColor3 = ScreenKit.Colors.White,
		TextScaled = true,
	}) :: TextBox

	const submit = function()
		const code = string.upper((string.gsub(codeBox.Text, "%s", "")))
		codeBox.Text = code
		if props.OnJoinCode and #code == CODE_LENGTH then
			props.OnJoinCode(code)
		end
	end

	codeBox.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			submit()
		end
	end)

	return ScreenKit.screen({
		Name = "JoinRoomScreen",
		Visible = props.Visible,
		Children = {
			ScreenKit.panel(),
			ScreenKit.header(function()
				const status = if props.Status then props.Status() else ""
				return if status ~= "" then status else "JOIN ROOM"
			end),

			create("Frame")({
				Name = "Code",
				Position = at(LIST_X, 140),
				Size = at(250, 43),
				BackgroundTransparency = 1,

				codeBox,
			}),

			ScreenKit.pressable({
				Name = "JoinCode",
				Position = at(395, 140),
				Size = at(150, 43),
				Color = ScreenKit.Colors.Orange,
				OnActivated = submit,
				Children = { ScreenKit.label("JOIN", 32, 43) },
			}),

			ScreenKit.pressable({
				Name = "Refresh",
				Position = at(822, 140),
				Size = at(170, 43),
				OnActivated = function()
					if props.OnRefresh then
						props.OnRefresh()
					end
				end,
				Children = {
					ScreenKit.label(function()
						return if loading() then "LOADING..." else "REFRESH"
					end, 28, 43),
				},
			}),

			create("ScrollingFrame")({
				Name = "List",
				Position = at(LIST_X, LIST_Y),
				Size = at(LIST_WIDTH, LIST_HEIGHT),
				BackgroundTransparency = 1,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = ScreenKit.Colors.White,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				CanvasSize = function()
					return UDim2.fromScale(0, math.max(total() * ROW_STEP / LIST_HEIGHT, 1))
				end,

				indexes(rooms, function(room, index)
					return row(room, index, props)
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
						return if loading() then "LOADING..." else "NO PUBLIC ROOMS"
					end,
					Position = at(LIST_X, 300),
					Size = at(LIST_WIDTH, 30),
					FontSize = 26,
					BoxHeight = 30,
				}),
			}),

			ScreenKit.returnButton(481, props.OnClose),
		},
	})
end
