--!strict
export type Slider = {
	Id: string,
	Label: string,
	Min: number,
	Max: number,
	Default: number,
	ProfileField: string?,
	Step: number?,
}

export type Choice = {
	Id: string,
	Label: string,
	Options: { string },
	Default: number,
}

export type CrosshairEntry = {
	Kind: "Slider" | "Choice" | "Preset",
	Id: string,
}

export type CrosshairPreset = {
	Id: string,
	Label: string,
	Values: { [string]: number },
}

export type CrosshairSection = {
	Label: string,
	Entries: { CrosshairEntry },
}

export type Keybind = {
	Id: string,
	Label: string,
	Default: string,
}

const KEY_LABELS: { [string]: string } = {
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
	Six = "6",
	Seven = "7",
	Eight = "8",
	Nine = "9",
	Zero = "0",
	LeftShift = "L SHIFT",
	RightShift = "R SHIFT",
	LeftControl = "L CTRL",
	RightControl = "R CTRL",
	LeftAlt = "L ALT",
	RightAlt = "R ALT",
	Space = "SPACE",
	Return = "ENTER",
	Backspace = "BACKSPACE",
}

const OptionsCatalog = {}

OptionsCatalog.Sliders = {
	{ Id = "MouseSensitivity", Label = "MOUSE SENSITIVITY", Min = 0.1, Max = 2, Default = 1 },
	{ Id = "ControllerSensitivity", Label = "CONTROLLER SENSITIVITY", Min = 0.1, Max = 2, Default = 1 },
	{ Id = "AimSensitivity", Label = "AIM SENSITIVITY", Min = 0.2, Max = 1.5, Default = 1 },
	{ Id = "SniperSensitivity", Label = "SNIPER SENSITIVITY", Min = 0.2, Max = 1.5, Default = 1 },
	{ Id = "Fov", Label = "FOV", Min = 60, Max = 110, Default = 70 },
} :: { Slider }

OptionsCatalog.AudioSliders = {
	{ Id = "MusicVolume", Label = "MUSIC", Min = 0, Max = 1, Default = 1, ProfileField = "MusicVolume" },
	{ Id = "SoundVolume", Label = "SOUND", Min = 0, Max = 1, Default = 1, ProfileField = "SoundVolume" },
} :: { Slider }

OptionsCatalog.Choices = {
	{ Id = "Language", Label = "LANGUAGE", Options = { "ENGLISH", "PORTUGUÊS" }, Default = 1 },
	{ Id = "ToggleCrouch", Label = "TOGGLE CROUCH", Options = { "OFF", "ON" }, Default = 2 },
	{ Id = "InvertY", Label = "INVERT Y", Options = { "OFF", "ON" }, Default = 1 },
} :: { Choice }

OptionsCatalog.Keybinds = {
	{ Id = "Crouch", Label = "CROUCH", Default = "C" },
	{ Id = "Reload", Label = "RELOAD", Default = "R" },
	{ Id = "SwitchSlot1", Label = "SLOT 1", Default = "One" },
	{ Id = "SwitchSlot2", Label = "SLOT 2", Default = "Two" },
	{ Id = "SwitchSlot3", Label = "SLOT 3", Default = "Three" },
	{ Id = "Leaderstats", Label = "SCOREBOARD", Default = "Tab" },
	{ Id = "UnlockCamera", Label = "FREE CURSOR", Default = "LeftAlt" },
	{ Id = "Options", Label = "MENU", Default = "M" },
	{ Id = "Practice", Label = "PRACTICE MENU", Default = "B" },
} :: { Keybind }

const TOGGLE = { "OFF", "ON" }

OptionsCatalog.CrosshairColors = {
	{ Name = "WHITE", Color = Color3.fromRGB(255, 255, 255) },
	{ Name = "GREEN", Color = Color3.fromRGB(0, 255, 0) },
	{ Name = "YELLOW", Color = Color3.fromRGB(255, 240, 0) },
	{ Name = "CYAN", Color = Color3.fromRGB(0, 255, 255) },
	{ Name = "RED", Color = Color3.fromRGB(255, 40, 40) },
	{ Name = "PINK", Color = Color3.fromRGB(255, 80, 200) },
}

local function colorNames(): { string }
	const names: { string } = {}
	for _, entry in OptionsCatalog.CrosshairColors do
		table.insert(names, entry.Name)
	end
	return names
end

OptionsCatalog.CrosshairSliders = {
	{ Id = "XhairOutlineOpacity", Label = "OUTLINE OPACITY", Min = 0, Max = 1, Default = 0.5, Step = 0.05 },
	{ Id = "XhairDotSize", Label = "DOT SIZE", Min = 1, Max = 8, Default = 2, Step = 1 },
	{ Id = "XhairDotOpacity", Label = "DOT OPACITY", Min = 0, Max = 1, Default = 1, Step = 0.05 },
	{ Id = "XhairInnerLength", Label = "LENGTH", Min = 0, Max = 20, Default = 6, Step = 1 },
	{ Id = "XhairInnerThickness", Label = "THICKNESS", Min = 1, Max = 10, Default = 2, Step = 1 },
	{ Id = "XhairInnerOffset", Label = "OFFSET", Min = 0, Max = 20, Default = 4, Step = 1 },
	{ Id = "XhairInnerOpacity", Label = "OPACITY", Min = 0, Max = 1, Default = 0.9, Step = 0.05 },
	{ Id = "XhairOuterLength", Label = "LENGTH", Min = 0, Max = 20, Default = 2, Step = 1 },
	{ Id = "XhairOuterThickness", Label = "THICKNESS", Min = 1, Max = 10, Default = 2, Step = 1 },
	{ Id = "XhairOuterOffset", Label = "OFFSET", Min = 0, Max = 40, Default = 10, Step = 1 },
	{ Id = "XhairOuterOpacity", Label = "OPACITY", Min = 0, Max = 1, Default = 0.35, Step = 0.05 },
} :: { Slider }

OptionsCatalog.CrosshairChoices = {
	{ Id = "XhairColor", Label = "COLOR", Options = colorNames(), Default = 1 },
	{ Id = "XhairOutline", Label = "OUTLINE", Options = TOGGLE, Default = 2 },
	{ Id = "XhairDot", Label = "CENTER DOT", Options = TOGGLE, Default = 1 },
	{ Id = "XhairInnerShow", Label = "SHOW LINES", Options = TOGGLE, Default = 2 },
	{ Id = "XhairInnerMovement", Label = "MOVEMENT ERROR", Options = TOGGLE, Default = 1 },
	{ Id = "XhairInnerFiring", Label = "FIRING ERROR", Options = TOGGLE, Default = 2 },
	{ Id = "XhairOuterShow", Label = "SHOW LINES", Options = TOGGLE, Default = 1 },
	{ Id = "XhairOuterMovement", Label = "MOVEMENT ERROR", Options = TOGGLE, Default = 2 },
	{ Id = "XhairOuterFiring", Label = "FIRING ERROR", Options = TOGGLE, Default = 2 },
} :: { Choice }

OptionsCatalog.CrosshairPresets = {
	{ Id = "Default", Label = "DEFAULT", Values = {} },
	{
		Id = "Classic",
		Label = "CLASSIC",
		Values = { XhairInnerLength = 6, XhairInnerOffset = 3, XhairInnerOpacity = 1, XhairInnerMovement = 2 },
	},
	{
		Id = "Dot",
		Label = "DOT ONLY",
		Values = { XhairInnerShow = 1, XhairDot = 2, XhairDotSize = 4, XhairDotOpacity = 1 },
	},
	{
		Id = "Dynamic",
		Label = "DYNAMIC",
		Values = {
			XhairInnerLength = 4,
			XhairInnerOffset = 2,
			XhairInnerOpacity = 1,
			XhairInnerFiring = 1,
			XhairOuterShow = 2,
			XhairOuterLength = 3,
			XhairOuterOffset = 8,
			XhairOuterOpacity = 0.6,
		},
	},
	{
		Id = "Tiny",
		Label = "TINY",
		Values = {
			XhairColor = 4,
			XhairInnerLength = 2,
			XhairInnerThickness = 1,
			XhairInnerOffset = 2,
			XhairInnerOpacity = 1,
			XhairInnerFiring = 1,
			XhairDot = 2,
			XhairDotSize = 1,
		},
	},
	{
		Id = "Spray",
		Label = "SPRAY",
		Values = {
			XhairColor = 3,
			XhairInnerLength = 8,
			XhairInnerOffset = 6,
			XhairInnerOpacity = 1,
			XhairInnerMovement = 2,
		},
	},
	{
		Id = "Plus",
		Label = "PLUS",
		Values = {
			XhairColor = 2,
			XhairInnerLength = 7,
			XhairInnerOffset = 0,
			XhairInnerOpacity = 1,
			XhairInnerFiring = 1,
		},
	},
} :: { CrosshairPreset }

local function presetEntries(): { CrosshairEntry }
	const entries: { CrosshairEntry } = {}
	for _, preset in OptionsCatalog.CrosshairPresets do
		const entry: CrosshairEntry = { Kind = "Preset", Id = preset.Id }
		table.insert(entries, entry)
	end
	return entries
end

OptionsCatalog.CrosshairSections = {
	{
		Label = "GENERAL",
		Entries = {
			{ Kind = "Choice", Id = "XhairColor" },
			{ Kind = "Choice", Id = "XhairOutline" },
			{ Kind = "Slider", Id = "XhairOutlineOpacity" },
			{ Kind = "Choice", Id = "XhairDot" },
			{ Kind = "Slider", Id = "XhairDotSize" },
			{ Kind = "Slider", Id = "XhairDotOpacity" },
		},
	},
	{
		Label = "INNER LINES",
		Entries = {
			{ Kind = "Choice", Id = "XhairInnerShow" },
			{ Kind = "Slider", Id = "XhairInnerLength" },
			{ Kind = "Slider", Id = "XhairInnerThickness" },
			{ Kind = "Slider", Id = "XhairInnerOffset" },
			{ Kind = "Slider", Id = "XhairInnerOpacity" },
			{ Kind = "Choice", Id = "XhairInnerMovement" },
			{ Kind = "Choice", Id = "XhairInnerFiring" },
		},
	},
	{
		Label = "OUTER LINES",
		Entries = {
			{ Kind = "Choice", Id = "XhairOuterShow" },
			{ Kind = "Slider", Id = "XhairOuterLength" },
			{ Kind = "Slider", Id = "XhairOuterThickness" },
			{ Kind = "Slider", Id = "XhairOuterOffset" },
			{ Kind = "Slider", Id = "XhairOuterOpacity" },
			{ Kind = "Choice", Id = "XhairOuterMovement" },
			{ Kind = "Choice", Id = "XhairOuterFiring" },
		},
	},
} :: { CrosshairSection }

table.insert(OptionsCatalog.CrosshairSections, 1, { Label = "PRESETS", Entries = presetEntries() })

local function concat<T>(first: { T }, second: { T }): { T }
	const result = table.clone(first)
	for _, entry in second do
		table.insert(result, entry)
	end
	return result
end

local function index<T>(list: { T }): { [string]: T }
	const map: { [string]: T } = {}
	for _, entry in list :: { any } do
		map[entry.Id] = entry
	end
	return map
end

OptionsCatalog.SliderById = index(concat(OptionsCatalog.Sliders, OptionsCatalog.CrosshairSliders))
OptionsCatalog.AudioSliderById = index(OptionsCatalog.AudioSliders)
OptionsCatalog.ChoiceById = index(concat(OptionsCatalog.Choices, OptionsCatalog.CrosshairChoices))
OptionsCatalog.KeybindById = index(OptionsCatalog.Keybinds)
OptionsCatalog.CrosshairPresetById = index(OptionsCatalog.CrosshairPresets)

function OptionsCatalog.CrosshairIds(): { string }
	const ids: { string } = {}
	for _, slider in OptionsCatalog.CrosshairSliders do
		table.insert(ids, slider.Id)
	end
	for _, choice in OptionsCatalog.CrosshairChoices do
		table.insert(ids, choice.Id)
	end
	return ids
end

function OptionsCatalog.FindSlider(id: string): Slider?
	return OptionsCatalog.SliderById[id] or OptionsCatalog.AudioSliderById[id]
end

function OptionsCatalog.ToFraction(slider: Slider, value: number): number
	return math.clamp((value - slider.Min) / (slider.Max - slider.Min), 0, 1)
end

function OptionsCatalog.FromFraction(slider: Slider, fraction: number): number
	return slider.Min + math.clamp(fraction, 0, 1) * (slider.Max - slider.Min)
end

function OptionsCatalog.Clamp(slider: Slider, value: number): number
	const clamped = math.clamp(value, slider.Min, slider.Max)
	const step = slider.Step
	if not step or step <= 0 then
		return clamped
	end
	return math.clamp(math.round(clamped / step) * step, slider.Min, slider.Max)
end

function OptionsCatalog.Display(slider: Slider, value: number): string
	const step = slider.Step
	if step and step >= 1 then
		return tostring(math.round(value))
	end
	return `{math.round(OptionsCatalog.ToFraction(slider, value) * 100)}%`
end

function OptionsCatalog.ParseKey(name: string): Enum.KeyCode?
	const ok, keyCode = pcall(function()
		return Enum.KeyCode:FromName(name)
	end)
	if not ok or keyCode == nil or keyCode.Name == "Unknown" then
		return nil
	end
	return keyCode :: Enum.KeyCode
end

function OptionsCatalog.KeyLabel(name: string): string
	return KEY_LABELS[name] or string.upper(name)
end

return OptionsCatalog
