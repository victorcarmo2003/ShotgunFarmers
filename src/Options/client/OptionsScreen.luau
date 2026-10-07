--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ScreenKit = require(StarterPlayer.StarterPlayerScripts.client.Interface.ScreenKit)
local Crosshair = require(StarterPlayer.StarterPlayerScripts.client.Weapon.Crosshair)

const create = Vide.create
const source = Vide.source
const show = Vide.show
const cleanup = Vide.cleanup
const untrack = Vide.untrack

const at = ScreenKit.at

const ROW_TOP = 132
const ROW_STEP = 45
const ROW_HEIGHT = 45
const LABEL_X = 297
const LABEL_WIDTH = 225
const VALUE_X = 551
const CONTROL_X = 634
const CONTROL_WIDTH = 190
const SLIDER_HEIGHT = 19
const TRACK_HEIGHT = 8
const KNOB_STROKE = 2
const DIVIDER_COUNT = 8
const DIVIDER_TRANSPARENCY = 0.85

const KEY_ROW_TOP = 139
const KEY_X = 699
const KEY_WIDTH = 125
const CLEAR_X = 595
const CLEAR_WIDTH = 79
const KEY_HEIGHT = 30

export type Tab = "Gameplay" | "Audio" | "Video" | "Keybinds" | "Crosshair"

export type Slider = {
	Id: string,
	Label: string,
	Value: number,
	Display: string?,
}

export type CrosshairRow = {
	Kind: "Slider" | "Choice" | "Preset",
	Id: string,
	Label: string,
	Value: number,
	Display: string,
	Text: string,
}

export type CrosshairSection = {
	Label: string,
	Rows: { CrosshairRow },
}

export type Choice = {
	Id: string,
	Label: string,
	Value: string,
}

export type Keybind = {
	Id: string,
	Label: string,
	Key: string,
}

export type Props = {
	Visible: (() -> boolean)?,
	Sliders: (() -> { Slider })?,
	AudioSliders: (() -> { Slider })?,
	Capturing: (() -> string?)?,
	Choices: (() -> { Choice })?,
	Keybinds: (() -> { Keybind })?,
	CrosshairSections: (() -> { CrosshairSection })?,
	CrosshairPreview: (() -> Crosshair.Config)?,
	OnPreset: ((id: string) -> ())?,
	OnSlider: ((id: string, value: number) -> ())?,
	OnSliderEnd: ((id: string) -> ())?,
	OnChoice: ((id: string, direction: number) -> ())?,
	OnRebind: ((id: string) -> ())?,
	OnClear: ((id: string) -> ())?,
	OnClose: (() -> ())?,
	ShowLeave: (() -> boolean)?,
	LeaveText: (() -> string)?,
	OnLeave: (() -> ())?,
}

const TABS: { { Tab: Tab, Label: string, X: number } } = {
	{ Tab = "Gameplay", Label = "GAMEPLAY", X = 272 },
	{ Tab = "Audio", Label = "AUDIO", X = 395 },
	{ Tab = "Video", Label = "VIDEO", X = 511 },
	{ Tab = "Keybinds", Label = "KEYBINDS", X = 627 },
	{ Tab = "Crosshair", Label = "CROSSHAIR", X = 743 },
}

const CROSSHAIR_ROWS = 7
const PREVIEW_X = 865
const PREVIEW_SIZE = 200

const SLIDER_ROWS = { 0, 1, 2, 3, 4 }
const AUDIO_ROWS = { 0, 1 }
const CHOICE_ROWS = { 5, 6, 7 }

const DEFAULT_SLIDERS: { Slider } = {
	{ Id = "MouseSensitivity", Label = "MOUSE SENSITIVITY", Value = 0.8 },
	{ Id = "ControllerSensitivity", Label = "CONTROLLER SENSITIVITY", Value = 0.8 },
	{ Id = "AimSensitivity", Label = "AIM SENSITIVITY", Value = 0.8 },
	{ Id = "SniperSensitivity", Label = "SNIPER SENSITIVITY", Value = 0.8 },
	{ Id = "Fov", Label = "FOV", Value = 0.8 },
}

const DEFAULT_AUDIO_SLIDERS: { Slider } = {
	{ Id = "MusicVolume", Label = "MUSIC", Value = 1 },
	{ Id = "SoundVolume", Label = "SOUND", Value = 1 },
}

const DEFAULT_CHOICES: { Choice } = {
	{ Id = "Language", Label = "LANGUAGE", Value = "ENGLISH" },
	{ Id = "ToggleCrouch", Label = "TOGGLE CROUCH", Value = "ON" },
	{ Id = "InvertY", Label = "INVERT Y", Value = "OFF" },
}

const DEFAULT_KEYBINDS: { Keybind } = {
	{ Id = "Crouch", Label = "CROUCH", Key = "C" },
	{ Id = "Reload", Label = "RELOAD", Key = "R" },
	{ Id = "Options", Label = "MENU", Key = "M" },
}

const CAPTURE_TEXT = "..."

local function constant<T>(value: T): () -> T
	return function()
		return value
	end
end

local function rowY(row: number): number
	return ROW_TOP + ROW_STEP * row
end

local function rowLabel(name: string, text: () -> string, y: number, height: number): Frame
	return ScreenKit.text({
		Name = name,
		Text = text,
		Position = at(LABEL_X, y),
		Size = at(LABEL_WIDTH, height),
		FontSize = 24,
		BoxHeight = height,
		XAlignment = Enum.TextXAlignment.Left,
	})
end

local function tabButton(entry: { Tab: Tab, Label: string, X: number }, selected: Vide.Source<Tab>): ImageButton
	return create("ImageButton")({
		Name = entry.Tab,
		Position = function()
			return if selected() == entry.Tab then at(entry.X, 78) else at(entry.X, 81)
		end,
		Size = function()
			return if selected() == entry.Tab then at(109, 48) else at(109, 45)
		end,
		BackgroundColor3 = ScreenKit.Colors.Black,
		BackgroundTransparency = function()
			return if selected() == entry.Tab then 0 else ScreenKit.DARK_TRANSPARENCY
		end,
		AutoButtonColor = false,

		Activated = function()
			selected(entry.Tab)
		end,

		ScreenKit.label(entry.Label, 24, 45),
	})
end

local function slider(sliders: () -> { Slider }, index: number, row: number, props: Props): { Instance }
	const y = rowY(row)

	const value = function(): number
		const entry = sliders()[index]
		return if entry then math.clamp(entry.Value, 0, 1) else 0
	end

	const id = function(): string?
		const entry = sliders()[index]
		return if entry then entry.Id else nil
	end

	local button: ImageButton? = nil
	local dragInput: InputObject? = nil
	local moved: RBXScriptConnection? = nil
	local released: RBXScriptConnection? = nil

	local function fractionAt(position: Vector3): number
		const target = button
		if not target or target.AbsoluteSize.X <= 0 then
			return 0
		end
		return math.clamp((position.X - target.AbsolutePosition.X) / target.AbsoluteSize.X, 0, 1)
	end

	local function emit(fraction: number)
		const current = id()
		const onSlider = props.OnSlider
		if current and onSlider then
			onSlider(current, fraction)
		end
	end

	local function disconnect()
		if moved then
			moved:Disconnect()
			moved = nil
		end
		if released then
			released:Disconnect()
			released = nil
		end
		dragInput = nil
	end

	local function finish()
		if dragInput == nil then
			return
		end

		disconnect()
		const current = id()
		const onSliderEnd = props.OnSliderEnd
		if current and onSliderEnd then
			onSliderEnd(current)
		end
	end

	cleanup(disconnect)

	local function begin(input: InputObject)
		if dragInput ~= nil then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		dragInput = input
		emit(fractionAt(input.Position))

		moved = UserInputService.InputChanged:Connect(function(changed: InputObject)
			if changed.UserInputType == Enum.UserInputType.MouseMovement or changed == dragInput then
				emit(fractionAt(changed.Position))
			end
		end)

		released = UserInputService.InputEnded:Connect(function(ended: InputObject)
			if ended == dragInput or ended.UserInputType == Enum.UserInputType.MouseButton1 then
				finish()
			end
		end)
	end

	const instance = create("ImageButton")({
		Name = `Slider{index}`,
		Position = at(CONTROL_X, y + (ROW_HEIGHT - SLIDER_HEIGHT) / 2),
		Size = at(CONTROL_WIDTH, SLIDER_HEIGHT),
		BackgroundTransparency = 1,
		AutoButtonColor = false,

		InputBegan = begin,

		create("Frame")({
			Name = "Track",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromScale(1, TRACK_HEIGHT / SLIDER_HEIGHT),
			BackgroundColor3 = ScreenKit.Colors.White,

			create("UICorner")({ CornerRadius = UDim.new(1, 0) }),

			create("Frame")({
				Name = "Fill",
				Size = function()
					return UDim2.fromScale(value(), 1)
				end,
				BackgroundColor3 = ScreenKit.Colors.Green,

				create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			}),
		}),

		create("Frame")({
			Name = "Knob",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = function()
				return UDim2.fromScale(value(), 0.5)
			end,
			Size = UDim2.fromScale(SLIDER_HEIGHT / CONTROL_WIDTH, 1),
			BackgroundColor3 = ScreenKit.Colors.White,

			create("UIAspectRatioConstraint")({ AspectRatio = 1 }),
			create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			ScreenKit.stroke(ScreenKit.Colors.Black, KNOB_STROKE),
		}),
	})
	button = instance

	return {
		rowLabel(`Slider{index}Label`, function()
			const entry = sliders()[index]
			return if entry then entry.Label else ""
		end, y, ROW_HEIGHT),

		ScreenKit.text({
			Name = `Slider{index}Value`,
			Text = function()
				const entry = sliders()[index]
				if entry and entry.Display then
					return entry.Display
				end
				return `{math.round(value() * 100)}%`
			end,
			Position = at(VALUE_X, y),
			Size = at(62, ROW_HEIGHT),
			FontSize = 24,
			BoxHeight = ROW_HEIGHT,
		}),

		instance,
	}
end

local function arrow(name: string, text: string, x: number, y: number, onActivated: () -> ()): ImageButton
	return create("ImageButton")({
		Name = name,
		Position = at(x, y),
		Size = at(14, 23),
		BackgroundTransparency = 1,
		AutoButtonColor = false,

		Activated = function()
			onActivated()
		end,

		ScreenKit.label(text, 23, 23),
	})
end

local function choice(choices: () -> { Choice }, index: number, row: number, props: Props): { Instance }
	const y = rowY(row)

	const entry = function(): Choice?
		return choices()[index]
	end

	const isLanguage = function(): boolean
		const current = entry()
		return current ~= nil and current.Id == "Language"
	end

	local function step(direction: number)
		const current = entry()
		if current and props.OnChoice then
			props.OnChoice(current.Id, direction)
		end
	end

	const valueText = function(): string
		const current = entry()
		return if current then current.Value else ""
	end

	return {
		rowLabel(`Choice{index}Label`, function()
			const current = entry()
			return if current then current.Label else ""
		end, y, ROW_HEIGHT),

		if untrack(isLanguage)
			then create("Frame")({
				Name = `Choice{index}Value`,
				Position = at(671, y + 11),
				Size = at(116, 28),
				BackgroundColor3 = ScreenKit.Colors.Green,

				ScreenKit.label(valueText, 24, 28),
			})
			else ScreenKit.text({
				Name = `Choice{index}Value`,
				Text = valueText,
				Position = at(CONTROL_X, y),
				Size = at(CONTROL_WIDTH, ROW_HEIGHT),
				FontSize = 24,
				BoxHeight = ROW_HEIGHT,
			}),

		arrow(`Choice{index}Previous`, "<", CONTROL_X, y + 11, function()
			step(-1)
		end),
		arrow(`Choice{index}Next`, ">", CONTROL_X + CONTROL_WIDTH - 15, y + 11, function()
			step(1)
		end),
	}
end

local function keybindRow(keybinds: () -> { Keybind }, index: number, props: Props): { Instance }
	const y = KEY_ROW_TOP + ROW_STEP * (index - 1)

	const entry = function(): Keybind?
		return keybinds()[index]
	end

	return {
		rowLabel(`Key{index}Label`, function()
			const current = entry()
			return if current then current.Label else ""
		end, y, KEY_HEIGHT),

		ScreenKit.pressable({
			Name = `Key{index}Clear`,
			Position = at(CLEAR_X, y),
			Size = at(CLEAR_WIDTH, KEY_HEIGHT),
			OnActivated = function()
				const current = entry()
				if current and props.OnClear then
					props.OnClear(current.Id)
				end
			end,
			Children = { ScreenKit.label("CLEAR", 24, KEY_HEIGHT) },
		}),

		ScreenKit.pressable({
			Name = `Key{index}Bind`,
			Position = at(KEY_X, y),
			Size = at(KEY_WIDTH, KEY_HEIGHT),
			OnActivated = function()
				const current = entry()
				if current and props.OnRebind then
					props.OnRebind(current.Id)
				end
			end,
			Children = {
				ScreenKit.label(function()
					const current = entry()
					if not current then
						return ""
					end
					const capturing = props.Capturing
					return if capturing and capturing() == current.Id then CAPTURE_TEXT else current.Key
				end, 24, KEY_HEIGHT),
			},
		}),
	}
end

local function sectionPicker(sections: () -> { CrosshairSection }, current: Vide.Source<number>): { Instance }
	const y = rowY(0)

	local function step(direction: number)
		const count = #sections()
		if count == 0 then
			return
		end
		current((current() - 1 + direction) % count + 1)
	end

	return {
		rowLabel("SectionLabel", function()
			return "SECTION"
		end, y, ROW_HEIGHT),

		create("Frame")({
			Name = "SectionValue",
			Position = at(CONTROL_X + 20, y + 9),
			Size = at(CONTROL_WIDTH - 40, 28),
			BackgroundColor3 = ScreenKit.Colors.Green,

			ScreenKit.label(function()
				const section = sections()[current()]
				return if section then section.Label else ""
			end, 22, 28),
		}),

		arrow("SectionPrevious", "<", CONTROL_X, y + 11, function()
			step(-1)
		end),
		arrow("SectionNext", ">", CONTROL_X + CONTROL_WIDTH - 15, y + 11, function()
			step(1)
		end),
	}
end

local function crosshairRow(
	sections: () -> { CrosshairSection },
	current: () -> number,
	row: number,
	props: Props
): { Instance }
	const entry = function(): CrosshairRow?
		const section = sections()[current()]
		return if section then section.Rows[row] else nil
	end

	const kindIs = function(kind: string): () -> boolean
		return function()
			const value = entry()
			return value ~= nil and value.Kind == kind
		end
	end

	return {
		create("Folder")({
			Name = `XhairRow{row}`,
			show(kindIs("Slider"), function()
				return create("Folder")({
					Name = `XhairSlider{row}`,
					slider(function(): { Slider }
						const value = entry()
						if not value then
							return {}
						end
						return { { Id = value.Id, Label = value.Label, Value = value.Value, Display = value.Display } }
					end, 1, row, props),
				})
			end),
			show(kindIs("Preset"), function()
				const y = rowY(row)
				return create("Folder")({
					Name = `XhairPreset{row}`,
					rowLabel(`XhairPreset{row}Label`, function()
						const value = entry()
						return if value then value.Label else ""
					end, y, ROW_HEIGHT),
					ScreenKit.pressable({
						Name = `XhairPreset{row}Apply`,
						Position = at(CONTROL_X + 35, y + 7),
						Size = at(CONTROL_WIDTH - 70, 31),
						OnActivated = function()
							const value = entry()
							if value and props.OnPreset then
								props.OnPreset(value.Id)
							end
						end,
						Children = { ScreenKit.label("APPLY", 22, 31) },
					}),
				})
			end),
			show(kindIs("Choice"), function()
				return create("Folder")({
					Name = `XhairChoice{row}`,
					choice(function(): { Choice }
						const value = entry()
						if not value then
							return {}
						end
						return { { Id = value.Id, Label = value.Label, Value = value.Text } }
					end, 1, row, props),
				})
			end),
		}),
	}
end

local function flatten(groups: { { Instance } }): { Instance }
	const result: { Instance } = {}
	for _, group in groups do
		for _, instance in group do
			table.insert(result, instance)
		end
	end
	return result
end

return function(props: Props): Frame
	const sliders = props.Sliders or constant(DEFAULT_SLIDERS)
	const audioSliders = props.AudioSliders or constant(DEFAULT_AUDIO_SLIDERS)
	const choices = props.Choices or constant(DEFAULT_CHOICES)
	const keybinds = props.Keybinds or constant(DEFAULT_KEYBINDS)
	const selected = source("Gameplay" :: Tab)

	const tabs: { Instance } = {}
	for _, entry in TABS do
		table.insert(tabs, tabButton(entry, selected))
	end

	const dividers: { Instance } = {}
	for index = 1, DIVIDER_COUNT do
		table.insert(
			dividers,
			create("Frame")({
				Name = `Divider{index}`,
				Position = at(290, 176 + ROW_STEP * (index - 1)),
				Size = at(541, 2),
				BorderSizePixel = 0,
				BackgroundColor3 = ScreenKit.Colors.White,
				BackgroundTransparency = DIVIDER_TRANSPARENCY,
			})
		)
	end

	return ScreenKit.screen({
		Name = "OptionsScreen",
		Visible = props.Visible,
		Children = {
			ScreenKit.text({
				Name = "Title",
				Text = "OPTIONS",
				Position = at(438, 29),
				Size = at(229, 47),
				FontSize = 48,
				BoxHeight = 47,
			}),

			tabs,

			create("Frame")({
				Name = "Panel",
				Position = at(272, 132),
				Size = at(578, 405),
				BackgroundColor3 = ScreenKit.Colors.Black,
				BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,
			}),

			dividers,

			show(function()
				return selected() == "Gameplay"
			end, function()
				const groups: { { Instance } } = {}
				for index, row in SLIDER_ROWS do
					table.insert(groups, slider(sliders, index, row, props))
				end
				for index = 1, #CHOICE_ROWS do
					table.insert(groups, choice(choices, index, CHOICE_ROWS[index], props))
				end
				return create("Folder")({ Name = "Gameplay", flatten(groups) })
			end),

			show(function()
				return selected() == "Audio"
			end, function()
				const groups: { { Instance } } = {}
				for index, row in AUDIO_ROWS do
					table.insert(groups, slider(audioSliders, index, row, props))
				end
				return create("Folder")({ Name = "Audio", flatten(groups) })
			end),

			show(function()
				return selected() == "Keybinds"
			end, function()
				const groups: { { Instance } } = {}
				for index = 1, untrack(function()
					return #keybinds()
				end) do
					table.insert(groups, keybindRow(keybinds, index, props))
				end
				return create("Folder")({ Name = "Keybinds", flatten(groups) })
			end),

			show(function()
				return selected() == "Crosshair" and props.CrosshairSections ~= nil
			end, function()
				const sections = props.CrosshairSections :: () -> { CrosshairSection }
				const current = source(1)
				const groups: { { Instance } } = { sectionPicker(sections, current) }
				for row = 1, CROSSHAIR_ROWS do
					table.insert(groups, crosshairRow(sections, current, row, props))
				end

				const preview = props.CrosshairPreview
				if preview then
					table.insert(groups, {
						create("Frame")({
							Name = "CrosshairPreview",
							Position = at(PREVIEW_X, 132),
							Size = at(PREVIEW_SIZE, PREVIEW_SIZE),
							BackgroundColor3 = ScreenKit.Colors.Black,
							BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,
							ClipsDescendants = true,

							Crosshair.new({
								Name = "Preview",
								Config = preview,
								Movement = constant(0),
								Firing = constant(0),
							}),
						}),
					})
				end

				return create("Folder")({ Name = "Crosshair", flatten(groups) })
			end),

			ScreenKit.pressable({
				Name = "Close",
				Position = at(470, 551),
				Size = at(162, 43),
				OnActivated = props.OnClose,
				Children = { ScreenKit.label("CLOSE", 40, 43) },
			}),

			show(function()
				return if props.ShowLeave then props.ShowLeave() else false
			end, function()
				return ScreenKit.pressable({
					Name = "LeaveMatch",
					Position = at(648, 551),
					Size = at(202, 43),
					Color = ScreenKit.Colors.Orange,
					OnActivated = props.OnLeave,
					Children = {
						ScreenKit.label(function()
							return if props.LeaveText then props.LeaveText() else "LEAVE MATCH"
						end, 32, 43),
					},
				})
			end),
		},
	})
end
