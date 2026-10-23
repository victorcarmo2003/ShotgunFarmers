--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local CreateRaw = require(ReplicatedStorage.shared.Interface.CreateRaw)
local Fonts = require(ReplicatedStorage.shared.Interface.Fonts)
local ShopCatalog = require(ReplicatedStorage.shared.Shop.ShopCatalog)
local SkinCatalog = require(ReplicatedStorage.shared.Shop.SkinCatalog)
local ScreenKit = require(StarterPlayer.StarterPlayerScripts.client.Interface.ScreenKit)

const create = Vide.create
const values = Vide.values
const source = Vide.source

const at = ScreenKit.at
const inside = ScreenKit.inside
const label = ScreenKit.label

const CARD_WIDTH = 176
const CARD_HEIGHT = 299
const BUTTON_WIDTH = 148
const BUTTON_HEIGHT = 31
const ROW_WIDTH = 785
const CARD_GAP = 27
const PAGE_SIZE = 4
const ARROW_WIDTH = 36
const ARROW_HEIGHT = 60
const TAB_WIDTH = 140
const TAB_HEIGHT = 28
const TAB_GAP = 12
const TAB_X = 168
const TAB_Y = 136
const DISABLED_COLOR = Color3.fromRGB(90, 90, 90)
const CODE_COLOR = Color3.fromHex("#8B00C2")
const BOOSTS_ID = "Boosts"
const BOOSTS_NAME = "BOOSTS"
const STORE_VIEW = "Store"
const CODE_VIEW = "Code"
const FOCUS_DELAY = 0.05
const CODE_BUTTON_X = 855
const BOTTOM_Y = 479
const CODE_BOX_WIDTH = 400
const CODE_BOX_HEIGHT = 52
const CODE_BOX_X = 361
const CODE_BOX_Y = 255
const REDEEM_WIDTH = 240
const REDEEM_HEIGHT = 45
const COW_BASE = Color3.fromRGB(244, 240, 232)
const COW_SPOT = Color3.fromRGB(22, 22, 26)
const SPOT_COUNT = 4
const SPOT_TRANSPARENCY = 0.78
const PREVIEW_TRANSPARENCY = 0.1
const SPOT_ANCHORS: { Vector2 } = {
	Vector2.new(0.04, 0.1),
	Vector2.new(0.96, 0.3),
	Vector2.new(0.08, 0.62),
	Vector2.new(0.94, 0.86),
	Vector2.new(0.5, 1),
	Vector2.new(0.55, 0),
}
const CARD_BORDER_COLOR = Color3.new(0, 0, 0)
const DESCRIPTION_COLOR = Color3.fromRGB(232, 232, 232)
const DESCRIPTION_MAX_TEXT = 17

const RarityColors: { [SkinCatalog.Rarity]: Color3 } = {
	Common = Color3.fromHex("#6B6B6B"),
	Rare = Color3.fromHex("#2F6FC6"),
	Epic = Color3.fromHex("#8E2FC6"),
	Legendary = Color3.fromHex("#D98A00"),
}

export type Item = SkinCatalog.Skin

type Entry = { Skin: Item?, Product: ShopCatalog.Item? }

type TabEntry = { Id: string, Name: string }

export type Props = {
	Visible: (() -> boolean)?,
	Items: (() -> { Item })?,
	Owned: (() -> { [string]: boolean })?,
	Equipped: (() -> { [string]: string })?,
	OnBuyRobux: ((id: string) -> ())?,
	OnBuyCoins: ((id: string) -> ())?,
	OnEquip: ((id: string) -> ())?,
	OnRedeemCode: ((code: string) -> ())?,
	OnClose: (() -> ())?,
}

local function priceButton(
	name: string,
	y: number,
	price: ScreenKit.Text,
	color: Color3,
	icon: string,
	iconPosition: UDim2,
	iconSize: UDim2,
	onActivated: () -> ()
): Frame
	return ScreenKit.pressable({
		Name = name,
		Position = inside(14, y, CARD_WIDTH, CARD_HEIGHT),
		Size = inside(BUTTON_WIDTH, BUTTON_HEIGHT, CARD_WIDTH, CARD_HEIGHT),
		Color = color,
		OnActivated = onActivated,
		Children = {
			create("Frame")({
				Name = "Price",
				Position = inside(29, 0, BUTTON_WIDTH, BUTTON_HEIGHT),
				Size = inside(89, BUTTON_HEIGHT, BUTTON_WIDTH, BUTTON_HEIGHT),
				BackgroundTransparency = 1,

				label(price, 31, BUTTON_HEIGHT),
			}),

			create("ImageLabel")({
				Name = "Icon",
				Position = iconPosition,
				Size = iconSize,
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				Image = icon,
			}),
		},
	})
end

local function seedOf(text: string): number
	local seed = 0
	for index = 1, #text do
		seed = (seed * 31 + string.byte(text, index)) % 1000003
	end
	return seed
end

local function spot(x: number, y: number, width: number, height: number, rotation: number): Frame
	return create("Frame")({
		Name = "Spot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(width, height),
		Rotation = rotation,
		BackgroundColor3 = COW_SPOT,
		BorderSizePixel = 0,

		create("UICorner")({
			CornerRadius = UDim.new(0.5, 0),
		}),
	})
end

local function cowSpots(id: string): CanvasGroup
	const random = Random.new(seedOf(id))
	const aspect = CARD_WIDTH / CARD_HEIGHT
	const anchors = table.clone(SPOT_ANCHORS)
	for index = #anchors, 2, -1 do
		const swap = random:NextInteger(1, index)
		anchors[index], anchors[swap] = anchors[swap], anchors[index]
	end

	const spots: { Instance } = {}
	for index = 1, SPOT_COUNT do
		const anchor = anchors[index]
		const x = anchor.X + random:NextNumber(-0.05, 0.05)
		const y = anchor.Y + random:NextNumber(-0.04, 0.04)
		const width = random:NextNumber(0.34, 0.5)
		const rotation = random:NextNumber(0, 180)
		table.insert(spots, spot(x, y, width, width * aspect * random:NextNumber(0.7, 0.95), rotation))
		table.insert(
			spots,
			spot(
				x + width * random:NextNumber(0.25, 0.45),
				y - width * aspect * random:NextNumber(0.1, 0.3),
				width * 0.55,
				width * aspect * 0.5,
				rotation + random:NextNumber(-35, 35)
			)
		)
		table.insert(
			spots,
			spot(
				x - width * random:NextNumber(0.2, 0.4),
				y + width * aspect * random:NextNumber(0.15, 0.3),
				width * 0.45,
				width * aspect * 0.4,
				rotation + random:NextNumber(-35, 35)
			)
		)
	end

	return create("CanvasGroup")({
		Name = "Spots",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = SPOT_TRANSPARENCY,
		ZIndex = 0,

		spots,
	})
end

local function preview(image: string, title: string): Frame
	return create("Frame")({
		Name = "Preview",
		Position = inside(14, 14, CARD_WIDTH, CARD_HEIGHT),
		Size = inside(148, 150, CARD_WIDTH, CARD_HEIGHT),
		BackgroundColor3 = ScreenKit.Colors.Black,
		BackgroundTransparency = PREVIEW_TRANSPARENCY,

		create("ImageLabel")({
			Name = "Image",
			Position = inside(8, 8, 148, 150),
			Size = inside(132, 100, 148, 150),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Image = image,
		}),

		ScreenKit.text({
			Name = "Title",
			Text = title,
			Position = inside(0, 112, 148, 150),
			Size = inside(148, 34, 148, 150),
			FontSize = 22,
			BoxHeight = 34,
		}),
	})
end

local function itemCard(props: Props, item: Item, index: () -> number): Frame
	const owned = function(): boolean
		return props.Owned ~= nil and props.Owned()[item.Id] == true
	end
	const equipped = function(): boolean
		return props.Equipped ~= nil and props.Equipped()[item.Gun] == item.Id
	end

	return create("Frame")({
		Name = item.Id,
		Size = UDim2.fromScale(CARD_WIDTH / ROW_WIDTH, 1),
		BackgroundColor3 = COW_BASE,
		ClipsDescendants = true,
		LayoutOrder = index,

		cowSpots(item.Id),

		preview(item.Preview, item.Name),

		ScreenKit.text({
			Name = "Rarity",
			Text = string.upper(item.Rarity),
			Position = inside(14, 170, CARD_WIDTH, CARD_HEIGHT),
			Size = inside(148, 24, CARD_WIDTH, CARD_HEIGHT),
			FontSize = 20,
			BoxHeight = 24,
			Color = RarityColors[item.Rarity],
		}),

		create("Frame")({
			Name = "Purchase",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = function()
				return not owned()
			end,

			priceButton(
				"BuyRobux",
				200,
				tostring(item.RobuxPrice),
				ScreenKit.Colors.Green,
				ScreenKit.Images.Robux,
				inside(121, 3, BUTTON_WIDTH, BUTTON_HEIGHT),
				inside(23, 25, BUTTON_WIDTH, BUTTON_HEIGHT),
				function()
					if props.OnBuyRobux then
						props.OnBuyRobux(item.Id)
					end
				end
			),

			priceButton(
				"BuyCoins",
				242,
				tostring(item.CoinPrice),
				ScreenKit.Colors.Orange,
				ScreenKit.Images.Coin,
				inside(120, 4, BUTTON_WIDTH, BUTTON_HEIGHT),
				inside(25, 24, BUTTON_WIDTH, BUTTON_HEIGHT),
				function()
					if props.OnBuyCoins then
						props.OnBuyCoins(item.Id)
					end
				end
			),
		}),

		create("Frame")({
			Name = "Owned",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = owned,

			ScreenKit.pressable({
				Name = "Equip",
				Position = inside(14, 221, CARD_WIDTH, CARD_HEIGHT),
				Size = inside(BUTTON_WIDTH, BUTTON_HEIGHT, CARD_WIDTH, CARD_HEIGHT),
				Color = function()
					return if equipped() then ScreenKit.Colors.Orange else ScreenKit.Colors.Green
				end,
				OnActivated = function()
					if props.OnEquip then
						props.OnEquip(item.Id)
					end
				end,
				Children = {
					label(function()
						return if equipped() then "EQUIPPED" else "EQUIP"
					end, 24, BUTTON_HEIGHT),
				},
			}),
		}),
	})
end

local function productCard(props: Props, item: ShopCatalog.Item, index: () -> number): Frame
	return create("Frame")({
		Name = item.Id,
		Size = UDim2.fromScale(CARD_WIDTH / ROW_WIDTH, 1),
		BackgroundColor3 = item.Color,
		LayoutOrder = index,

		create("Frame")({
			Name = "Preview",
			Position = inside(14, 14, CARD_WIDTH, CARD_HEIGHT),
			Size = inside(148, 124, CARD_WIDTH, CARD_HEIGHT),
			BackgroundColor3 = ScreenKit.Colors.Black,
			BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,

			create("ImageLabel")({
				Name = "Image",
				Position = inside(14, 6, 148, 124),
				Size = inside(120, 74, 148, 124),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				Image = item.Image or "",
			}),

			ScreenKit.text({
				Name = "Title",
				Text = item.Name,
				Position = inside(0, 86, 148, 124),
				Size = inside(148, 34, 148, 124),
				FontSize = 22,
				BoxHeight = 34,
			}),
		}),

		create("TextLabel")({
			Name = "Description",
			Position = inside(14, 146, CARD_WIDTH, CARD_HEIGHT),
			Size = inside(148, 94, CARD_WIDTH, CARD_HEIGHT),
			BackgroundTransparency = 1,
			FontFace = Fonts.FredokaOne,
			Text = item.Description,
			TextColor3 = DESCRIPTION_COLOR,
			TextWrapped = true,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,

			CreateRaw("UITextSizeConstraint")({
				MaxTextSize = DESCRIPTION_MAX_TEXT,
			}),
		}),

		priceButton(
			"BuyRobux",
			255,
			tostring(item.RobuxPrice),
			ScreenKit.Colors.Green,
			ScreenKit.Images.Robux,
			inside(121, 3, BUTTON_WIDTH, BUTTON_HEIGHT),
			inside(23, 25, BUTTON_WIDTH, BUTTON_HEIGHT),
			function()
				if props.OnBuyRobux then
					props.OnBuyRobux(item.Id)
				end
			end
		),
	})
end

local function arrow(name: string, symbol: string, x: number, enabled: () -> boolean, onActivated: () -> ()): Frame
	return ScreenKit.pressable({
		Name = name,
		Position = at(x, 300),
		Size = at(ARROW_WIDTH, ARROW_HEIGHT),
		Color = function()
			return if enabled() then ScreenKit.Colors.Green else DISABLED_COLOR
		end,
		OnActivated = function()
			if enabled() then
				onActivated()
			end
		end,
		Children = {
			label(symbol, 44, ARROW_HEIGHT),
		},
	})
end

local function tab(name: string, text: string, index: number, active: () -> boolean, onActivated: () -> ()): Frame
	return ScreenKit.pressable({
		Name = name,
		Position = at(TAB_X + (index - 1) * (TAB_WIDTH + TAB_GAP), TAB_Y),
		Size = at(TAB_WIDTH, TAB_HEIGHT),
		Color = function()
			return if active() then ScreenKit.Colors.Green else DISABLED_COLOR
		end,
		OnActivated = onActivated,
		Children = {
			label(text, 22, TAB_HEIGHT),
		},
	})
end

return function(props: Props): Frame
	const items: () -> { Item } = props.Items or function()
		return SkinCatalog.Skins
	end

	const tabEntries: { TabEntry } = {}
	for _, entry in SkinCatalog.Categories do
		table.insert(tabEntries, { Id = entry.Id, Name = entry.Name })
	end
	table.insert(tabEntries, { Id = BOOSTS_ID, Name = BOOSTS_NAME })

	const view = source(STORE_VIEW)
	const category = source(tabEntries[1].Id)
	const page = source(1)

	const shown = function(): { Entry }
		const list: { Entry } = {}
		if category() == BOOSTS_ID then
			for _, product in ShopCatalog.Items do
				table.insert(list, { Product = product })
			end
			return list
		end

		for _, item in items() do
			if item.Category == category() then
				table.insert(list, { Skin = item })
			end
		end
		return list
	end
	const pageCount = function(): number
		return math.max(1, math.ceil(#shown() / PAGE_SIZE))
	end
	const visibleItems = function(): { Entry }
		const list = shown()
		const first = (math.min(page(), pageCount()) - 1) * PAGE_SIZE
		const slice: { Entry } = {}
		for index = first + 1, math.min(first + PAGE_SIZE, #list) do
			table.insert(slice, list[index])
		end
		return slice
	end

	const tabs: { Instance } = {}
	for index, entry in tabEntries do
		table.insert(
			tabs,
			tab("Tab" .. entry.Id, entry.Name, index, function()
				return category() == entry.Id
			end, function()
				category(entry.Id)
				page(1)
			end)
		)
	end

	const codeBox = create("TextBox")({
		Name = "Input",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = ScreenKit.Colors.Black,
		BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,
		ClearTextOnFocus = false,
		FontFace = ScreenKit.Font,
		PlaceholderText = "TYPE YOUR CODE",
		PlaceholderColor3 = Color3.fromRGB(170, 170, 170),
		Text = "",
		TextColor3 = ScreenKit.Colors.White,
		TextScaled = true,
	}) :: TextBox

	const submit = function()
		const code = string.upper((string.gsub(codeBox.Text, "%s", "")))
		if code == "" then
			return
		end
		if props.OnRedeemCode then
			props.OnRedeemCode(code)
		end
		codeBox.Text = ""
	end

	codeBox.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			submit()
		end
	end)

	Vide.effect(function()
		if props.Visible and not props.Visible() then
			view(STORE_VIEW)
		end
	end)

	return ScreenKit.screen({
		Name = "ShopScreen",
		Visible = props.Visible,
		Children = {
			ScreenKit.panel(),
			ScreenKit.header(function()
				return if view() == CODE_VIEW then "CODE" else "SHOP"
			end),

			create("Frame")({
				Name = "Store",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Visible = function()
					return view() == STORE_VIEW
				end,

				tabs,

				arrow("Previous", "<", 124, function()
					return page() > 1
				end, function()
					page(page() - 1)
				end),

				create("Frame")({
					Name = "Items",
					Position = at(168, 170),
					Size = at(ROW_WIDTH, CARD_HEIGHT),
					BackgroundTransparency = 1,

					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(CARD_GAP / ROW_WIDTH, 0),
					}),

					values(visibleItems, function(entry: Entry, index: () -> number)
						const skin = entry.Skin
						if skin then
							return itemCard(props, skin, index)
						end
						return productCard(props, entry.Product :: ShopCatalog.Item, index)
					end),
				}),

				arrow("Next", ">", 962, function()
					return page() < pageCount()
				end, function()
					page(page() + 1)
				end),

				ScreenKit.text({
					Name = "Page",
					Text = function()
						return `{math.min(page(), pageCount())} / {pageCount()}`
					end,
					Position = at(461, 474),
					Size = at(200, 30),
					FontSize = 26,
					BoxHeight = 30,
				}),

				ScreenKit.pressable({
					Name = "CodeButton",
					Position = at(CODE_BUTTON_X, BOTTOM_Y),
					Size = at(154, 33),
					Color = CODE_COLOR,
					OnActivated = function()
						view(CODE_VIEW)
						task.delay(FOCUS_DELAY, function()
							codeBox:CaptureFocus()
						end)
					end,
					Children = { label("CODE", 26, 33) },
				}),
			}),

			create("Frame")({
				Name = "Redeem",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Visible = function()
					return view() == CODE_VIEW
				end,

				ScreenKit.text({
					Name = "Title",
					Text = "ENTER CODE",
					Position = at(CODE_BOX_X, 180),
					Size = at(CODE_BOX_WIDTH, 52),
					FontSize = 44,
					BoxHeight = 52,
				}),

				create("Frame")({
					Name = "Code",
					Position = at(CODE_BOX_X, CODE_BOX_Y),
					Size = at(CODE_BOX_WIDTH, CODE_BOX_HEIGHT),
					BackgroundTransparency = 1,

					codeBox,

				}),

				ScreenKit.pressable({
					Name = "Redeem",
					Position = at(CODE_BOX_X + (CODE_BOX_WIDTH - REDEEM_WIDTH) / 2, CODE_BOX_Y + CODE_BOX_HEIGHT + 30),
					Size = at(REDEEM_WIDTH, REDEEM_HEIGHT),
					Color = ScreenKit.Colors.Green,
					OnActivated = submit,
					Children = { label("REDEEM", 32, REDEEM_HEIGHT) },
				}),
			}),

			ScreenKit.returnButton(BOTTOM_Y, function()
				if view() == CODE_VIEW then
					view(STORE_VIEW)
				elseif props.OnClose then
					props.OnClose()
				end
			end, false),
		},
	})
end
