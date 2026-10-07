--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ShopCatalog = require(ReplicatedStorage.shared.Shop.ShopCatalog)
local ScreenKit = require(StarterPlayer.StarterPlayerScripts.client.Interface.ScreenKit)

const create = Vide.create
const values = Vide.values

const at = ScreenKit.at
const inside = ScreenKit.inside
const label = ScreenKit.label

const CARD_WIDTH = 176
const CARD_HEIGHT = 299
const BUTTON_WIDTH = 148
const BUTTON_HEIGHT = 31
const ROW_WIDTH = 785
const CARD_GAP = 27

export type Item = ShopCatalog.Item

export type Props = {
	Visible: (() -> boolean)?,
	Items: (() -> { Item })?,
	OnBuyRobux: ((id: string) -> ())?,
	OnBuyCoins: ((id: string) -> ())?,
	OnClose: (() -> ())?,
}

local function priceButton(name: string, y: number, price: number, color: Color3, icon: string, iconPosition: UDim2, iconSize: UDim2, onActivated: () -> ()): Frame
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

				label(tostring(price), 31, BUTTON_HEIGHT),
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

local function itemCard(props: Props, item: Item, index: () -> number): Frame
	return create("Frame")({
		Name = item.Id,
		Size = UDim2.fromScale(CARD_WIDTH / ROW_WIDTH, 1),
		BackgroundColor3 = item.Color,
		LayoutOrder = index,

		create("Frame")({
			Name = "Preview",
			Position = inside(14, 16, CARD_WIDTH, CARD_HEIGHT),
			Size = inside(148, 193, CARD_WIDTH, CARD_HEIGHT),
			BackgroundColor3 = ScreenKit.Colors.Black,
			BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,

			create("ImageLabel")({
				Name = "Image",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				Image = item.Image or "",
			}),
		}),

		priceButton(
			"BuyRobux",
			219,
			item.RobuxPrice,
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
			259,
			item.CoinPrice,
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
	})
end

return function(props: Props): Frame
	const items = props.Items or function()
		return ShopCatalog.Items
	end

	return ScreenKit.screen({
		Name = "ShopScreen",
		Visible = props.Visible,
		Children = {
			ScreenKit.panel(),
			ScreenKit.header("SHOP"),

			create("Frame")({
				Name = "Items",
				Position = at(168, 166),
				Size = at(ROW_WIDTH, CARD_HEIGHT),
				BackgroundTransparency = 1,

				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(CARD_GAP / ROW_WIDTH, 0),
				}),

				values(items, function(item: Item, index: () -> number)
					return itemCard(props, item, index)
				end),
			}),

			ScreenKit.returnButton(479, props.OnClose),
		},
	})
end
