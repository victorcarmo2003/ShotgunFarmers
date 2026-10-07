--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CreateRaw = require(ReplicatedStorage.shared.Interface.CreateRaw)
local OptionsCatalog = require(ReplicatedStorage.shared.Options.OptionsCatalog)
local Vide = require(ReplicatedStorage.Packages.Vide)

const create = Vide.create

const MOVEMENT_ERROR = 8
const FIRING_ERROR = 14
const OUTLINE_THICKNESS = 1

export type Lines = {
	Show: boolean,
	Length: number,
	Thickness: number,
	Offset: number,
	Opacity: number,
	Movement: boolean,
	Firing: boolean,
}

export type Config = {
	Color: Color3,
	Outline: boolean,
	OutlineOpacity: number,
	Dot: boolean,
	DotSize: number,
	DotOpacity: number,
	Inner: Lines,
	Outer: Lines,
}

export type Props = {
	Config: () -> Config,
	Movement: () -> number,
	Firing: () -> number,
	Visible: (() -> boolean)?,
	Name: string?,
}

type Direction = "Top" | "Bottom" | "Left" | "Right"

const DIRECTIONS: { Direction } = { "Top", "Bottom", "Left", "Right" }

local function lines(get: (string) -> number, prefix: string): Lines
	return {
		Show = get(`Xhair{prefix}Show`) >= 2,
		Length = get(`Xhair{prefix}Length`),
		Thickness = get(`Xhair{prefix}Thickness`),
		Offset = get(`Xhair{prefix}Offset`),
		Opacity = get(`Xhair{prefix}Opacity`),
		Movement = get(`Xhair{prefix}Movement`) >= 2,
		Firing = get(`Xhair{prefix}Firing`) >= 2,
	}
end

local function resolve(get: (string) -> number): Config
	const colorIndex = math.clamp(math.round(get("XhairColor")), 1, #OptionsCatalog.CrosshairColors)
	return {
		Color = OptionsCatalog.CrosshairColors[colorIndex].Color,
		Outline = get("XhairOutline") >= 2,
		OutlineOpacity = get("XhairOutlineOpacity"),
		Dot = get("XhairDot") >= 2,
		DotSize = get("XhairDotSize"),
		DotOpacity = get("XhairDotOpacity"),
		Inner = lines(get, "Inner"),
		Outer = lines(get, "Outer"),
	}
end

local function defaults(id: string): number
	const slider = OptionsCatalog.SliderById[id]
	if slider then
		return slider.Default
	end
	const choice = OptionsCatalog.ChoiceById[id]
	return if choice then choice.Default else 0
end

local function outline(props: Props, opacity: () -> number): UIStroke
	return CreateRaw("UIStroke")({
		Color = Color3.new(0, 0, 0),
		Thickness = OUTLINE_THICKNESS,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Miter,
		Enabled = function()
			return props.Config().Outline
		end,
		Transparency = function()
			return 1 - props.Config().OutlineOpacity * opacity()
		end,
	})
end

local function line(props: Props, pick: (Config) -> Lines, direction: Direction): Frame
	const vertical = direction == "Top" or direction == "Bottom"
	const sign = if direction == "Top" or direction == "Left" then -1 else 1

	const gap = function(): number
		const set = pick(props.Config())
		local value = set.Offset
		if set.Movement then
			value += props.Movement() * MOVEMENT_ERROR
		end
		if set.Firing then
			value += props.Firing() * FIRING_ERROR
		end
		return value
	end

	const opacity = function(): number
		return pick(props.Config()).Opacity
	end

	return create("Frame")({
		Name = direction,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		Visible = function()
			const set = pick(props.Config())
			return set.Show and set.Length > 0 and set.Opacity > 0
		end,
		BackgroundColor3 = function()
			return props.Config().Color
		end,
		BackgroundTransparency = function()
			return 1 - opacity()
		end,
		Size = function()
			const set = pick(props.Config())
			return if vertical
				then UDim2.fromOffset(set.Thickness, set.Length)
				else UDim2.fromOffset(set.Length, set.Thickness)
		end,
		Position = function()
			const set = pick(props.Config())
			const distance = math.round((gap() + set.Length / 2) * sign)
			return if vertical then UDim2.new(0.5, 0, 0.5, distance) else UDim2.new(0.5, distance, 0.5, 0)
		end,

		outline(props, opacity),
	})
end

local function lineSet(props: Props, name: string, pick: (Config) -> Lines): Frame
	const children: { Instance } = {}
	for _, direction in DIRECTIONS do
		table.insert(children, line(props, pick, direction))
	end

	return create("Frame")({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		children,
	})
end

local function new(props: Props): Frame
	const dotOpacity = function(): number
		return props.Config().DotOpacity
	end

	return create("Frame")({
		Name = props.Name or "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Visible = props.Visible,

		lineSet(props, "Outer", function(config)
			return config.Outer
		end),
		lineSet(props, "Inner", function(config)
			return config.Inner
		end),

		create("Frame")({
			Name = "Dot",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BorderSizePixel = 0,
			Visible = function()
				const config = props.Config()
				return config.Dot and config.DotOpacity > 0
			end,
			Size = function()
				const size = props.Config().DotSize
				return UDim2.fromOffset(size, size)
			end,
			BackgroundColor3 = function()
				return props.Config().Color
			end,
			BackgroundTransparency = function()
				return 1 - dotOpacity()
			end,

			outline(props, dotOpacity),
		}),
	})
end

return {
	new = new,
	Resolve = resolve,
	Defaults = function(): Config
		return resolve(defaults)
	end,
}
