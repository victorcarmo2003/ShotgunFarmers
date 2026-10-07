--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local CreateRaw = require(ReplicatedStorage.shared.Interface.CreateRaw)
local PracticeCatalog = require(ReplicatedStorage.shared.Practice.PracticeCatalog)
local Vide = require(ReplicatedStorage.Packages.Vide)
local ScreenKit = require(StarterPlayer.StarterPlayerScripts.client.Interface.ScreenKit)

const create = Vide.create

const at = ScreenKit.at
const inside = ScreenKit.inside

const PANEL_X = 52
const PANEL_Y = 84
const PANEL_WIDTH = 728
const PANEL_HEIGHT = 452
const PADDING = 14
const COLUMNS = 7
const CARD_WIDTH = 92
const CARD_HEIGHT = 74
const CARD_GAP = 8
const SECTION_HEADER = 30
const SECTION_GAP = 10
const CARD_NAME_HEIGHT = 20
const SCROLL_THICKNESS = 6

const SIDE_X = 798
const SIDE_WIDTH = 272
const SLOT_TOP = 120
const SLOT_HEIGHT = 46
const SLOT_GAP = 6
const SLOT_ICON = 46
const TOGGLE_TOP = 300
const TOGGLE_HEIGHT = 40
const ACTION_TOP = 400
const ACTION_HEIGHT = 43

const CARD_COLOR = Color3.fromRGB(28, 28, 28)
const SELECTED_STROKE = 3
const EMPTY_SLOT = "EMPTY"

const SLOT_LABELS = { "1  WEAPON", "2  GRENADE", "3  MELEE" }

export type Props = {
	Visible: (() -> boolean)?,
	Equipped: (() -> { number })?,
	InfiniteAmmo: (() -> boolean)?,
	InfiniteGrenades: (() -> boolean)?,
	OnSelect: ((id: number) -> ())?,
	OnToggleAmmo: (() -> ())?,
	OnToggleGrenades: (() -> ())?,
	OnRefill: (() -> ())?,
	OnRespawn: (() -> ())?,
	OnClose: (() -> ())?,
}

local function constant<T>(value: T): () -> T
	return function()
		return value
	end
end

local function rowsFor(count: number): number
	return math.max(math.ceil(count / COLUMNS), 1)
end

local function contentHeight(): number
	local height = PADDING
	for index, section in PracticeCatalog.Sections do
		height += SECTION_HEADER + rowsFor(#section.Entries) * (CARD_HEIGHT + CARD_GAP)
		if index < #PracticeCatalog.Sections then
			height += SECTION_GAP
		end
	end
	return height + PADDING
end

local function card(entry: PracticeCatalog.Entry, x: number, y: number, total: number, equipped: () -> { number }, props: Props): Frame
	const selected = function(): boolean
		return equipped()[entry.Slot] == entry.ID
	end

	const children: { Instance } = {
		create("Frame")({
			Name = "Caption",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, CARD_NAME_HEIGHT / CARD_HEIGHT),
			BackgroundTransparency = 1,
			ZIndex = 2,

			ScreenKit.label(string.upper(entry.Name), 14, CARD_NAME_HEIGHT),
		}),

		CreateRaw("UIStroke")({
			Color = ScreenKit.Colors.White,
			Thickness = SELECTED_STROKE,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Enabled = selected,
		}),
	}

	if entry.Image ~= "" then
		table.insert(
			children,
			create("ImageLabel")({
				Name = "Icon",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.06),
				Size = UDim2.fromScale(0.86, (CARD_HEIGHT - CARD_NAME_HEIGHT - 6) / CARD_HEIGHT),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				Image = entry.Image,
			})
		)
	else
		table.insert(
			children,
			create("Frame")({
				Name = "Initial",
				Size = UDim2.fromScale(1, (CARD_HEIGHT - CARD_NAME_HEIGHT) / CARD_HEIGHT),
				BackgroundTransparency = 1,

				ScreenKit.label(string.upper(string.sub(entry.Name, 1, 2)), 30, CARD_HEIGHT - CARD_NAME_HEIGHT),
			})
		)
	end

	return ScreenKit.pressable({
		Name = entry.Name,
		Position = inside(x, y, PANEL_WIDTH, total),
		Size = inside(CARD_WIDTH, CARD_HEIGHT, PANEL_WIDTH, total),
		Color = function()
			return if selected() then ScreenKit.Colors.Green else CARD_COLOR
		end,
		OnActivated = function()
			if props.OnSelect then
				props.OnSelect(entry.ID)
			end
		end,
		Children = children,
	})
end

local function grid(equipped: () -> { number }, props: Props): ScrollingFrame
	const total = contentHeight()
	const items: { Instance } = {}

	local y = PADDING
	for index, section in PracticeCatalog.Sections do
		table.insert(
			items,
			ScreenKit.text({
				Name = `{section.Category}Header`,
				Text = section.Label,
				Position = inside(PADDING, y, PANEL_WIDTH, total),
				Size = inside(PANEL_WIDTH - PADDING * 2, SECTION_HEADER, PANEL_WIDTH, total),
				FontSize = 22,
				BoxHeight = SECTION_HEADER,
				XAlignment = Enum.TextXAlignment.Left,
			})
		)
		y += SECTION_HEADER

		for position, entry in section.Entries do
			const column = (position - 1) % COLUMNS
			const row = (position - 1) // COLUMNS
			const x = PADDING + column * (CARD_WIDTH + CARD_GAP)
			table.insert(items, card(entry, x, y + row * (CARD_HEIGHT + CARD_GAP), total, equipped, props))
		end

		y += rowsFor(#section.Entries) * (CARD_HEIGHT + CARD_GAP)
		if index < #PracticeCatalog.Sections then
			y += SECTION_GAP
		end
	end

	return create("ScrollingFrame")({
		Name = "Catalog",
		Position = at(PANEL_X, PANEL_Y),
		Size = at(PANEL_WIDTH, PANEL_HEIGHT),
		BackgroundColor3 = ScreenKit.Colors.Black,
		BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, math.max(total / PANEL_HEIGHT, 1)),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = SCROLL_THICKNESS,
		ScrollBarImageColor3 = ScreenKit.Colors.White,

		items,
	})
end

local function slotRow(slot: number, equipped: () -> { number }): Frame
	const entry = function(): PracticeCatalog.Entry?
		const id = equipped()[slot]
		return if id and id > 0 then PracticeCatalog.ByID[id] else nil
	end

	return create("Frame")({
		Name = `Slot{slot}`,
		Position = at(SIDE_X, SLOT_TOP + (slot - 1) * (SLOT_HEIGHT + SLOT_GAP)),
		Size = at(SIDE_WIDTH, SLOT_HEIGHT),
		BackgroundColor3 = ScreenKit.Colors.Black,
		BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,

		create("ImageLabel")({
			Name = "Icon",
			Position = UDim2.fromScale(4 / SIDE_WIDTH, 0),
			Size = UDim2.fromScale(SLOT_ICON / SIDE_WIDTH, 1),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Image = function()
				const current = entry()
				return if current then current.Image else ""
			end,
		}),

		ScreenKit.text({
			Name = "Kind",
			Text = SLOT_LABELS[slot],
			Position = UDim2.fromScale((SLOT_ICON + 10) / SIDE_WIDTH, 2 / SLOT_HEIGHT),
			Size = UDim2.fromScale((SIDE_WIDTH - SLOT_ICON - 16) / SIDE_WIDTH, 18 / SLOT_HEIGHT),
			FontSize = 14,
			BoxHeight = 18,
			Color = ScreenKit.Colors.Orange,
			XAlignment = Enum.TextXAlignment.Left,
		}),

		ScreenKit.text({
			Name = "Gun",
			Text = function()
				const current = entry()
				return if current then string.upper(current.Name) else EMPTY_SLOT
			end,
			Position = UDim2.fromScale((SLOT_ICON + 10) / SIDE_WIDTH, 20 / SLOT_HEIGHT),
			Size = UDim2.fromScale((SIDE_WIDTH - SLOT_ICON - 16) / SIDE_WIDTH, 24 / SLOT_HEIGHT),
			FontSize = 22,
			BoxHeight = 24,
			XAlignment = Enum.TextXAlignment.Left,
		}),
	})
end

local function toggle(name: string, text: string, row: number, value: () -> boolean, onToggle: (() -> ())?): Frame
	return ScreenKit.pressable({
		Name = name,
		Position = at(SIDE_X, TOGGLE_TOP + row * (TOGGLE_HEIGHT + SLOT_GAP)),
		Size = at(SIDE_WIDTH, TOGGLE_HEIGHT),
		Color = function()
			return if value() then ScreenKit.Colors.Green else CARD_COLOR
		end,
		OnActivated = onToggle,
		Children = {
			ScreenKit.label(function()
				return `{text}: {if value() then "ON" else "OFF"}`
			end, 22, TOGGLE_HEIGHT),
		},
	})
end

return function(props: Props): Frame
	const equipped = props.Equipped or constant({ 0, 0, 0 })
	const infiniteAmmo = props.InfiniteAmmo or constant(false)
	const infiniteGrenades = props.InfiniteGrenades or constant(false)
	const halfWidth = (SIDE_WIDTH - SLOT_GAP) / 2

	return ScreenKit.screen({
		Name = "PracticeScreen",
		Visible = props.Visible,
		Children = {
			ScreenKit.text({
				Name = "Title",
				Text = "PRACTICE",
				Position = at(438, 24),
				Size = at(246, 47),
				FontSize = 48,
				BoxHeight = 47,
			}),

			grid(equipped, props),

			ScreenKit.text({
				Name = "EquippedHeader",
				Text = "EQUIPPED",
				Position = at(SIDE_X, PANEL_Y),
				Size = at(SIDE_WIDTH, 30),
				FontSize = 26,
				BoxHeight = 30,
				XAlignment = Enum.TextXAlignment.Left,
			}),

			slotRow(1, equipped),
			slotRow(2, equipped),
			slotRow(3, equipped),

			ScreenKit.text({
				Name = "CheatsHeader",
				Text = "CHEATS",
				Position = at(SIDE_X, TOGGLE_TOP - 34),
				Size = at(SIDE_WIDTH, 30),
				FontSize = 26,
				BoxHeight = 30,
				XAlignment = Enum.TextXAlignment.Left,
			}),

			toggle("InfiniteAmmo", "INFINITE AMMO", 0, infiniteAmmo, props.OnToggleAmmo),
			toggle("InfiniteGrenades", "INFINITE GRENADES", 1, infiniteGrenades, props.OnToggleGrenades),

			ScreenKit.pressable({
				Name = "Refill",
				Position = at(SIDE_X, ACTION_TOP),
				Size = at(halfWidth, ACTION_HEIGHT),
				OnActivated = props.OnRefill,
				Children = { ScreenKit.label("REFILL", 30, ACTION_HEIGHT) },
			}),

			ScreenKit.pressable({
				Name = "Respawn",
				Position = at(SIDE_X + halfWidth + SLOT_GAP, ACTION_TOP),
				Size = at(halfWidth, ACTION_HEIGHT),
				Color = ScreenKit.Colors.Orange,
				OnActivated = props.OnRespawn,
				Children = { ScreenKit.label("RESPAWN", 30, ACTION_HEIGHT) },
			}),

			ScreenKit.pressable({
				Name = "Close",
				Position = at(480, 551),
				Size = at(162, 43),
				OnActivated = props.OnClose,
				Children = { ScreenKit.label("CLOSE", 40, 43) },
			}),
		},
	})
end
