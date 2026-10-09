--!strict
export type Grant = "CropDrop" | "DoubleXp" | "Revival"

export type Item = {
	Id: string,
	Name: string,
	Color: Color3,
	RobuxPrice: number,
	CoinPrice: number?,
	Image: string?,
	ProductId: number,
	Grant: Grant,
}

const Items: { Item } = {
	{
		Id = "CropDrop",
		Name = "CROP DROP",
		Color = Color3.fromHex("#1F9F68"),
		RobuxPrice = 19,
		Image = "rbxassetid://104434605047747",
		ProductId = 3717365879,
		Grant = "CropDrop",
	},
	{
		Id = "DoubleXp",
		Name = "2X XP 1H",
		Color = Color3.fromHex("#FFBB00"),
		RobuxPrice = 25,
		Image = "rbxassetid://131378468365288",
		ProductId = 3717365826,
		Grant = "DoubleXp",
	},
	{
		Id = "Revival",
		Name = "REVIVAL TOKEN",
		Color = Color3.fromHex("#C62F2F"),
		RobuxPrice = 9,
		Image = "rbxassetid://111089067896192",
		ProductId = 3717365732,
		Grant = "Revival",
	},
}

local function byId(id: string): Item?
	for _, item in Items do
		if item.Id == id then
			return item
		end
	end
	return nil
end

local function byProduct(productId: number): Item?
	for _, item in Items do
		if item.ProductId == productId then
			return item
		end
	end
	return nil
end

return {
	Items = Items,
	ById = byId,
	ByProduct = byProduct,
	XP_BOOST_SECONDS = 3600,
	XP_BOOST_MULTIPLIER = 2,
	CROP_DROP_SECONDS = 30,
	CROP_DROP_INTERVAL = 1.2,
	CROP_DROP_MAX = 25,
	REVIVAL_ATTRIBUTE = "RevivalTokens",
	XP_BOOST_ATTRIBUTE = "XpBoostEnds",
	CROP_DROP_ATTRIBUTE = "CropDrops",
}
