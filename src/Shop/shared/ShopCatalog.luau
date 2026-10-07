--!strict
export type Item = {
	Id: string,
	Name: string,
	Color: Color3,
	RobuxPrice: number,
	CoinPrice: number,
	Image: string?,
}

const Items: { Item } = {
	{ Id = "Sample1", Name = "Sample 1", Color = Color3.fromHex("#8B00C2"), RobuxPrice = 300, CoinPrice = 300 },
	{ Id = "Sample2", Name = "Sample 2", Color = Color3.fromHex("#FFBB00"), RobuxPrice = 300, CoinPrice = 300 },
	{ Id = "Sample3", Name = "Sample 3", Color = Color3.fromHex("#FFFFFF"), RobuxPrice = 300, CoinPrice = 300 },
	{ Id = "Sample4", Name = "Sample 4", Color = Color3.fromHex("#FF00AA"), RobuxPrice = 300, CoinPrice = 300 },
}

return {
	Items = Items,
}
