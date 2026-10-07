--!strict

export type ScopeLighting = {
	LightColor: Color3,
	Ambient: Color3,
	HazeColor: Color3,
	HazeTransparency: number,
	SkyTop: Color3,
	SkyMid: Color3,
	SkyBottom: Color3,
}

export type Map = {
	DisplayName: string,
	Modes: { string },
	Lighting: string,
	DayCycle: boolean,
	ScopeLighting: ScopeLighting?,
}

const Maps: { [string]: Map } = {
	HappyFarm = {
		DisplayName = "Happy Farm",
		Modes = { "FFA", "TDM", "Chicken" },
		Lighting = "HappyFarm",
		DayCycle = false,
	},
	WildWest = {
		DisplayName = "Wild West",
		Modes = { "FFA", "TDM", "Chicken" },
		Lighting = "WildWest",
		DayCycle = false,
	},
	Practice = {
		DisplayName = "Practice Range",
		Modes = { "Practice" },
		Lighting = "Practice",
		DayCycle = false,
		ScopeLighting = {
			LightColor = Color3.new(1.42, 1.43, 1.38),
			Ambient = Color3.new(0.5, 0.47, 0.72),
			HazeColor = Color3.fromRGB(170, 200, 255),
			HazeTransparency = 0.9,
			SkyTop = Color3.fromRGB(30, 100, 235),
			SkyMid = Color3.fromRGB(140, 195, 255),
			SkyBottom = Color3.fromRGB(205, 230, 255),
		},
	},
}

return Maps
