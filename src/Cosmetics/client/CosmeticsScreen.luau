--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local CreateRaw = require(ReplicatedStorage.shared.Interface.CreateRaw)
local ScreenKit = require(StarterPlayer.StarterPlayerScripts.client.Interface.ScreenKit)

const create = Vide.create
const source = Vide.source

const at = ScreenKit.at
const inside = ScreenKit.inside
const label = ScreenKit.label

const OFFSET_Y = 10

const TAB_COUNT = 7
const TAB_SPACING = 50
const TAB_COLOR = Color3.fromHex("#0095FF")
const TAB_SELECTED_COLOR = Color3.fromHex("#FFAE00")
const TAB_ICON = "rbxassetid://122573838382015"

const SLOTS_PER_ROW = 5
const SLOT_SIZE = 69
const SLOT_SPACING = 89
const SECTION_TITLE_SPACING = 134
const SECTION_SLOT_SPACING = 136
const SLOT_STROKE = 3
const CHECK_IMAGE = "rbxassetid://123304100581473"

const CODE_COLOR = Color3.fromHex("#8B00C2")

export type Section = {
	Name: string,
	Items: { string },
}

export type Props = {
	Visible: (() -> boolean)?,
	Sections: (() -> { Section })?,
	OnSelectTab: ((index: number) -> ())?,
	OnSelectItem: ((section: string, index: number) -> ())?,
	OnCode: (() -> ())?,
	OnDone: (() -> ())?,
	OnClose: (() -> ())?,
}

const DEFAULT_SECTIONS: { Section } = {
	{ Name = "BODY", Items = { "", "", "", "", "" } },
	{ Name = "OUTFIT", Items = { "", "", "", "", "" } },
}

local function y(value: number): number
	return value + OFFSET_Y
end

local function tab(index: number, selectedTab: Vide.Source<number>, props: Props): Frame
	return ScreenKit.pressable({
		Name = `Tab{index}`,
		Position = at(44, y(37 + TAB_SPACING * (index - 1))),
		Size = at(51, 43),
		Color = function()
			return if selectedTab() == index then TAB_SELECTED_COLOR else TAB_COLOR
		end,
		OnActivated = function()
			selectedTab(index)
			if props.OnSelectTab then
				props.OnSelectTab(index)
			end
		end,
		Children = {
			create("ImageLabel")({
				Name = "Icon",
				Position = inside(6, 2, 51, 43),
				Size = inside(39, 39, 51, 43),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				Image = TAB_ICON,
			}),
		},
	})
end

local function slot(section: string, sectionIndex: number, index: number, image: string, selected: Vide.Source<{ [string]: number }>, props: Props): ImageButton
	return create("ImageButton")({
		Name = `Slot{index}`,
		Position = at(110 + SLOT_SPACING * (index - 1), y(95 + SECTION_SLOT_SPACING * (sectionIndex - 1))),
		Size = at(SLOT_SIZE, SLOT_SIZE),
		BackgroundTransparency = 1,
		Image = image,
		ScaleType = Enum.ScaleType.Fit,

		Activated = function()
			const current = table.clone(selected())
			current[section] = index
			selected(current)
			if props.OnSelectItem then
				props.OnSelectItem(section, index)
			end
		end,

		CreateRaw("UIStroke")({
			Color = ScreenKit.Colors.White,
			Thickness = SLOT_STROKE,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),

		create("ImageLabel")({
			Name = "Check",
			Position = inside(35, 38, SLOT_SIZE, SLOT_SIZE),
			Size = inside(27, 21, SLOT_SIZE, SLOT_SIZE),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Image = CHECK_IMAGE,
			Visible = function()
				return selected()[section] == index
			end,
		}),
	})
end

local function sectionTitle(name: string, sectionIndex: number): Frame
	return create("Frame")({
		Name = `{name}Title`,
		Position = at(110, y(42 + SECTION_TITLE_SPACING * (sectionIndex - 1))),
		Size = at(122, 44),
		BackgroundTransparency = 1,

		create("TextLabel")({
			Name = "Label",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromScale(1, 36 / 44),
			BackgroundTransparency = 1,
			FontFace = ScreenKit.Font,
			RichText = true,
			Text = `<b>{name}</b>`,
			TextColor3 = ScreenKit.Colors.White,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end

local function wideButton(name: string, text: string, x: number, color: Color3, onActivated: (() -> ())?): Frame
	return ScreenKit.pressable({
		Name = name,
		Position = at(x, y(498)),
		Size = at(190, 43),
		Color = color,
		OnActivated = onActivated,
		Children = { label(text, 36, 43) },
	})
end

return function(props: Props): Frame
	const sections = props.Sections or function()
		return DEFAULT_SECTIONS
	end
	const selectedTab = source(1)
	const selected = source({} :: { [string]: number })

	const tabs: { Instance } = {}
	for index = 1, TAB_COUNT do
		table.insert(tabs, tab(index, selectedTab, props))
	end

	const content: { Instance } = {}
	for sectionIndex, section in sections() do
		table.insert(content, sectionTitle(section.Name, sectionIndex))
		for index = 1, math.min(#section.Items, SLOTS_PER_ROW) do
			table.insert(content, slot(section.Name, sectionIndex, index, section.Items[index], selected, props))
		end
	end

	return ScreenKit.screen({
		Name = "CosmeticsScreen",
		Visible = props.Visible,
		Children = {
			create("Frame")({
				Name = "Panel",
				Position = at(95, y(37)),
				Size = at(455, 452),
				BackgroundColor3 = ScreenKit.Colors.Black,
				BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,
			}),

			tabs,
			content,

			wideButton("Code", "CODIGO", 95, CODE_COLOR, props.OnCode),
			wideButton("Done", "DONE", 360, ScreenKit.Colors.Green, function()
				if props.OnDone then
					props.OnDone()
				elseif props.OnClose then
					props.OnClose()
				end
			end),
		},
	})
end
