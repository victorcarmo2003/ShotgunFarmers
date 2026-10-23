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
	Image: string,
	Modes: { string },
	Lighting: string,
	DayCycle: boolean,
	Boundary: { string }?,
	ScopeLighting: ScopeLighting?,
}

const Maps: { [string]: Map } = {
	HappyFarm = {
		DisplayName = "Happy Farm",
		Image = "rbxassetid://88677777226273",
		Modes = { "FFA", "TDM", "Chicken" },
		Lighting = "HappyFarm",
		DayCycle = false,
		Boundary = { "CERCAS", "CERCA", "MUROPEDRA" },
	},
	WildWest = {
		DisplayName = "Magma Foundry",
		Image = "rbxassetid://87983370462029",
		Modes = { "FFA", "TDM", "Chicken" },
		Lighting = "WildWest",
		DayCycle = false,
		Boundary = { "Cerca" },
	},
	Practice = {
		DisplayName = "Practice Range",
		Image = "rbxassetid://124127914596658",
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
