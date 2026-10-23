--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local SkinCatalog = require(ReplicatedStorage.shared.Shop.SkinCatalog)
local ScreenKit = require(StarterPlayer.StarterPlayerScripts.client.Interface.ScreenKit)

const create = Vide.create
const source = Vide.source
const values = Vide.values

const at = ScreenKit.at
const inside = ScreenKit.inside
const label = ScreenKit.label

const OFFSET_Y = 10

const TAB_X = 44
const TAB_WIDTH = 51
const TAB_HEIGHT = 43
const TAB_SPACING = 50
const TAB_AREA_WIDTH = 56
const TAB_AREA_HEIGHT = 452
const TAB_SCROLL_THICKNESS = 4
const TAB_COLOR = Color3.fromHex("#0095FF")
const TAB_SELECTED_COLOR = Color3.fromHex("#FFAE00")

const PANEL_X = 95
const PANEL_WIDTH = 455
const PANEL_HEIGHT = 452

const SLOTS_PER_ROW = 5
const SLOT_SIZE = 69
const SLOT_SPACING = 89
const ROW_SPACING = 100
const SLOT_ORIGIN_X = 110
const SLOT_ORIGIN_Y = 95
const CAPTION_HEIGHT = 20
const SLOT_COLOR = Color3.fromRGB(28, 28, 28)
const LOCK_TRANSPARENCY = 0.35
const CHECK_IMAGE = "rbxassetid://123304100581473"
const DEFAULT_CAPTION = "DEFAULT"
const LOCKED_CAPTION = "LOCKED"

export type Category = {
	Gun: string,
	Image: string,
	Skins: { SkinCatalog.Skin },
}

type Slot = {
	Skin: SkinCatalog.Skin?,
	Gun: string,
	Image: string,
	Caption: string,
}

export type Props = {
	Visible: (() -> boolean)?,
	Categories: (() -> { Category })?,
	Owned: (() -> { [string]: boolean })?,
	Equipped: (() -> { [string]: string })?,
	OnEquip: ((id: string) -> ())?,
	OnEquipDefault: ((gun: string) -> ())?,
	OnSelectGun: ((gun: string) -> ())?,
	OnPreview: ((gun: string, id: string?) -> ())?,
	OnDone: (() -> ())?,
	OnClose: (() -> ())?,
}

local function y(value: number): number
	return value + OFFSET_Y
end

local function buildCategories(): { Category }
	const entries: { GetGun.GunData } = {}
	const all: { [string]: GetGun.GunData } = GetGun.All
	for _, gun in all do
		if not gun.Disabled and gun.ImageID ~= "" then
			table.insert(entries, gun)
		end
	end
	table.sort(entries, function(a: GetGun.GunData, b: GetGun.GunData): boolean
		return a.ID < b.ID
	end)

	const categories: { Category } = {}
	for _, gun in entries do
		const skins: { SkinCatalog.Skin } = {}
		for _, skin in SkinCatalog.Skins do
			if skin.Gun == gun.DisplayName then
				table.insert(skins, skin)
			end
		end
		table.insert(categories, { Gun = gun.DisplayName, Image = gun.ImageID, Skins = skins })
	end
	return categories
end

local function tab(index: number, category: Category, total: number, selectedTab: Vide.Source<number>): Frame
	return ScreenKit.pressable({
		Name = `Tab{category.Gun}`,
		Position = inside(0, TAB_SPACING * (index - 1), TAB_AREA_WIDTH, total),
		Size = inside(TAB_WIDTH, TAB_HEIGHT, TAB_AREA_WIDTH, total),
		Color = function()
			return if selectedTab() == index then TAB_SELECTED_COLOR else TAB_COLOR
		end,
		OnActivated = function()
			selectedTab(index)
		end,
		Children = {
			create("ImageLabel")({
				Name = "Icon",
				Position = inside(6, 2, TAB_WIDTH, TAB_HEIGHT),
				Size = inside(39, 39, TAB_WIDTH, TAB_HEIGHT),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				Image = category.Image,
			}),
		},
	})
end

local function tabColumn(categories: { Category }, selectedTab: Vide.Source<number>): ScrollingFrame
	const total = math.max(#categories * TAB_SPACING, TAB_AREA_HEIGHT)
	const tabs: { Instance } = {}
	for index, category in categories do
		table.insert(tabs, tab(index, category, total, selectedTab))
	end

	return create("ScrollingFrame")({
		Name = "Tabs",
		Position = at(TAB_X, y(37)),
		Size = at(TAB_AREA_WIDTH, TAB_AREA_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, total / TAB_AREA_HEIGHT),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = TAB_SCROLL_THICKNESS,
		ScrollBarImageColor3 = ScreenKit.Colors.White,

		tabs,
	})
end

local function slot(position: number, entry: Slot, props: Props): Frame
	const column = (position - 1) % SLOTS_PER_ROW
	const row = (position - 1) // SLOTS_PER_ROW
	const skin = entry.Skin

	const owned = function(): boolean
		if not skin then
			return true
		end
		return props.Owned ~= nil and props.Owned()[skin.Id] == true
	end
	const equipped = function(): boolean
		const current = if props.Equipped then props.Equipped()[entry.Gun] else nil
		if skin then
			return current == skin.Id
		end
		return current == nil
	end

	return create("Frame")({
		Name = `Slot{position}`,
		Position = at(SLOT_ORIGIN_X + SLOT_SPACING * column, y(SLOT_ORIGIN_Y + ROW_SPACING * row)),
		Size = at(SLOT_SIZE, SLOT_SIZE + CAPTION_HEIGHT),
		BackgroundTransparency = 1,

		ScreenKit.pressable({
			Name = "Button",
			Position = UDim2.fromScale(0, 0),
			Size = inside(SLOT_SIZE, SLOT_SIZE, SLOT_SIZE, SLOT_SIZE + CAPTION_HEIGHT),
			Color = SLOT_COLOR,
			OnActivated = function()
				if props.OnPreview then
					props.OnPreview(entry.Gun, if skin then skin.Id else nil)
				end
				if not skin then
					if props.OnEquipDefault then
						props.OnEquipDefault(entry.Gun)
					end
				elseif owned() then
					if props.OnEquip then
						props.OnEquip(skin.Id)
					end
				end
			end,
			Children = {
				create("ImageLabel")({
					Name = "Image",
					Position = inside(4, 4, SLOT_SIZE, SLOT_SIZE),
					Size = inside(SLOT_SIZE - 8, SLOT_SIZE - 8, SLOT_SIZE, SLOT_SIZE),
					BackgroundTransparency = 1,
					ScaleType = Enum.ScaleType.Fit,
					Image = entry.Image,
				}),

				create("Frame")({
					Name = "Lock",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = ScreenKit.Colors.Black,
					BackgroundTransparency = LOCK_TRANSPARENCY,
					BorderSizePixel = 0,
					ZIndex = 2,
					Visible = function()
						return not owned()
					end,

					ScreenKit.label(LOCKED_CAPTION, 14, SLOT_SIZE),
				}),

				create("ImageLabel")({
					Name = "Check",
					Position = inside(35, 38, SLOT_SIZE, SLOT_SIZE),
					Size = inside(27, 21, SLOT_SIZE, SLOT_SIZE),
					BackgroundTransparency = 1,
					ScaleType = Enum.ScaleType.Fit,
					Image = CHECK_IMAGE,
					ZIndex = 3,
					Visible = equipped,
				}),

			},
		}),

		ScreenKit.text({
			Name = "Caption",
			Text = entry.Caption,
			Position = inside(0, SLOT_SIZE + 2, SLOT_SIZE, SLOT_SIZE + CAPTION_HEIGHT),
			Size = inside(SLOT_SIZE, CAPTION_HEIGHT - 2, SLOT_SIZE, SLOT_SIZE + CAPTION_HEIGHT),
			FontSize = 14,
			BoxHeight = CAPTION_HEIGHT - 2,
		}),
	})
end

local function slotsFor(category: Category?): { Slot }
	if not category then
		return {}
	end

	const list: { Slot } = {
		{ Skin = nil, Gun = category.Gun, Image = category.Image, Caption = DEFAULT_CAPTION },
	}
	for _, skin in category.Skins do
		table.insert(list, {
			Skin = skin,
			Gun = category.Gun,
			Image = skin.Preview,
			Caption = string.upper(skin.Pack),
		})
	end
	return list
end

local function doneButton(onActivated: (() -> ())?): Frame
	return ScreenKit.pressable({
		Name = "Done",
		Position = at(PANEL_X + (PANEL_WIDTH - 190) / 2, y(498)),
		Size = at(190, 43),
		Color = ScreenKit.Colors.Green,
		OnActivated = onActivated,
		Children = { label("DONE", 36, 43) },
	})
end

return function(props: Props): Frame
	const categories: { Category } = if props.Categories then props.Categories() else buildCategories()
	const selectedTab = source(1)

	const selectedCategory = function(): Category?
		return categories[selectedTab()]
	end

	Vide.effect(function()
		const category = selectedCategory()
		const onSelect = props.OnSelectGun
		if category and onSelect then
			Vide.untrack(function()
				onSelect(category.Gun)
			end)
		end
	end)

	return ScreenKit.screen({
		Name = "CosmeticsScreen",
		Visible = props.Visible,
		Children = {
			create("Frame")({
				Name = "Panel",
				Position = at(PANEL_X, y(37)),
				Size = at(PANEL_WIDTH, PANEL_HEIGHT),
				BackgroundColor3 = ScreenKit.Colors.Black,
				BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,
			}),

			tabColumn(categories, selectedTab),

			ScreenKit.text({
				Name = "GunTitle",
				Text = function()
					const category = selectedCategory()
					return if category then string.upper(category.Gun) else ""
				end,
				Position = at(SLOT_ORIGIN_X, y(42)),
				Size = at(PANEL_WIDTH - 30, 44),
				FontSize = 36,
				BoxHeight = 44,
				XAlignment = Enum.TextXAlignment.Left,
			}),

			create("Frame")({
				Name = "Slots",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,

				values(function()
					return slotsFor(selectedCategory())
				end, function(entry: Slot, index: () -> number)
					return slot(index(), entry, props)
				end),
			}),

			doneButton(function()
				if props.OnDone then
					props.OnDone()
				elseif props.OnClose then
					props.OnClose()
				end
			end),
		},
	})
end
