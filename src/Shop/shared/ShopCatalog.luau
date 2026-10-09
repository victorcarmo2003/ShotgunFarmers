--!strict
export type Kind = "Product" | "Pass"

export type Item = {
	Id: string,
	Name: string,
	Kind: Kind,
	Color: Color3,
	RobuxPrice: number,
	CoinPrice: number?,
	Image: string?,
	AssetId: number,
	Gems: number?,
	GemMultiplier: number?,
}

const Items: { Item } = {
	{
		Id = "Gems100",
		Image = "rbxassetid://121901793473334",
		Name = "100 GEMS",
		Kind = "Product",
		Color = Color3.fromHex("#1F9F68"),
		RobuxPrice = 49,
		AssetId = 0,
		Gems = 100,
	},
	{
		Id = "Gems500",
		Image = "rbxassetid://124810481167748",
		Name = "500 GEMS",
		Kind = "Product",
		Color = Color3.fromHex("#2A7BD1"),
		RobuxPrice = 199,
		AssetId = 0,
		Gems = 500,
	},
	{
		Id = "Gems1200",
		Image = "rbxassetid://139090093784000",
		Name = "1200 GEMS",
		Kind = "Product",
		Color = Color3.fromHex("#8B00C2"),
		RobuxPrice = 399,
		AssetId = 0,
		Gems = 1200,
	},
	{
		Id = "DoubleGems",
		Image = "rbxassetid://108490785575131",
		Name = "2X GEMS",
		Kind = "Pass",
		Color = Color3.fromHex("#FFBB00"),
		RobuxPrice = 249,
		AssetId = 0,
		GemMultiplier = 2,
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

local function byAsset(kind: Kind, assetId: number): Item?
	for _, item in Items do
		if item.Kind == kind and item.AssetId == assetId and assetId ~= 0 then
			return item
		end
	end
	return nil
end

return {
	Items = Items,
	ById = byId,
	ByAsset = byAsset,
}
