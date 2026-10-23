--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary"
export type Resolution = "1k" | "2k"
export type Category = "Guns" | "Throwables"

export type Maps = {
	Color: string,
	Normal: string,
	Metalness: string,
	Roughness: string,
	Mesh: string?,
}

export type Skin = {
	Id: string,
	Name: string,
	Pack: string,
	Gun: string,
	Category: Category,
	Rarity: Rarity,
	CoinPrice: number,
	RobuxPrice: number,
	GamepassId: number,
	Preview: string,
	Textures: { [Resolution]: { [string]: Maps } },
}

local function maps(
	color: number,
	normal: number,
	metalness: number,
	roughness: number,
	mesh: string?
): Maps
	return {
		Color = `rbxassetid://{color}`,
		Normal = `rbxassetid://{normal}`,
		Metalness = `rbxassetid://{metalness}`,
		Roughness = `rbxassetid://{roughness}`,
		Mesh = mesh,
	}
end

const DEFAULT_PRICE = 300
const ROBUX_PRICE = 15
const ATTRIBUTE_PREFIX = "Skin_"
const MESH_FOLDER = "SkinMeshes"
const TEXTURE_FOLDER = "SkinTextures"
const DEFAULT_RARITY: Rarity = "Epic"
const COW = "Cow"

const THROWABLES: { [string]: boolean } = {
	Onionnade = true,
	Lemonade = true,
	Pinapple = true,
	Moolotov = true,
	Bananarang = true,
}

const GAMEPASS_IDS: { [string]: number } = {
	Cow_M6Bean = 0,
	Cow_Peavolver = 0,
	Cow_WatermeLMG = 0,
	Cow_Snipine = 0,
	Cow_Carrocket = 0,
	Cow_Onionnade = 0,
	Cow_Lemonade = 0,
	Cow_Pinapple = 0,
	Cow_Moolotov = 0,
	Cow_Bananarang = 0,
}

const Categories: { { Id: Category, Name: string } } = {
	{ Id = "Guns", Name = "GUNS" },
	{ Id = "Throwables", Name = "THROWABLES" },
}

local function skin(gun: string, preview: number, textures: { [Resolution]: { [string]: Maps } }): Skin
	return {
		Id = `{COW}_{gun}`,
		Name = `{COW} {gun}`,
		Pack = COW,
		Gun = gun,
		Category = if THROWABLES[gun] then "Throwables" else "Guns",
		Rarity = DEFAULT_RARITY,
		CoinPrice = DEFAULT_PRICE,
		RobuxPrice = ROBUX_PRICE,
		GamepassId = GAMEPASS_IDS[`{COW}_{gun}`] or 0,
		Preview = `rbxassetid://{preview}`,
		Textures = textures,
	}
end

const Skins: { Skin } = {
	skin("M6Bean", 97764292269477, {
		["1k"] = {
			["Cylinder.007"] = maps(70375559560405, 139331041744386, 100637943241949, 72662138227142),
			["Cylinder.008"] = maps(78523831209854, 136600097048691, 100637943241949, 72662138227142),
		},
		["2k"] = {
			["Cylinder.007"] = maps(79117239311031, 107686423625287, 122397518427237, 119736998253683),
			["Cylinder.008"] = maps(92617983422056, 125765067407086, 87329784274225, 117478438510208),
		},
	}),
	skin("Peavolver", 101599425049931, {
		["1k"] = {
			["Cylinder.005"] = maps(86242014591532, 84632881946854, 100637943241949, 72662138227142),
			["Cylinder.003"] = maps(98020865563716, 114184361483187, 100637943241949, 72662138227142),
		},
		["2k"] = {
			["Cylinder.005"] = maps(118757416072048, 78802027706210, 138134786519269, 86932946971397),
			["Cylinder.003"] = maps(104632517625283, 116645284782970, 81920777169849, 103819703565994),
		},
	}),
	skin("WatermeLMG", 105495828758269, {
		["1k"] = {
			["Cylinder.018"] = maps(71080766050751, 70588577019173, 100637943241949, 72662138227142),
			["Cylinder.009"] = maps(137841406878605, 77330398479897, 100637943241949, 72662138227142),
		},
		["2k"] = {
			["Cylinder.018"] = maps(95470787216287, 75784905185351, 89040148602731, 121281157864459),
			["Cylinder.009"] = maps(121804635393093, 71652585988149, 124274741213412, 90282397305904),
		},
	}),
	skin("Snipine", 134701800382545, {
		["1k"] = {
			["Cylinder.010"] = maps(127666494357654, 91083668567912, 100637943241949, 72662138227142),
		},
		["2k"] = {
			["Cylinder.010"] = maps(132144542850528, 122313725509076, 92017807410732, 100097516825702),
		},
	}),
	skin("Carrocket", 77542277209930, {
		["1k"] = {
			["Cylinder.019"] = maps(113068154929192, 128372765392714, 100637943241949, 72662138227142),
			["Cylinder.023"] = maps(113068154929192, 128372765392714, 100637943241949, 72662138227142),
		},
		["2k"] = {
			["Cylinder.019"] = maps(131373623602265, 115388736903479, 117953097375413, 111297127563968),
			["Cylinder.023"] = maps(131373623602265, 115388736903479, 117953097375413, 111297127563968),
		},
	}),
	skin("Onionnade", 102033154554055, {
		["1k"] = {
			["Cube"] = maps(118788498763894, 87492715614314, 100637943241949, 72662138227142, "Cow_Onionnade_Cube"),
			["Cylinder.015"] = maps(83637590251067, 88186915801273, 100637943241949, 72662138227142, "Cow_Onionnade_Cylinder.015"),
		},
		["2k"] = {
			["Cube"] = maps(129482132241508, 112448233598385, 129925118970492, 84109401080750, "Cow_Onionnade_Cube"),
			["Cylinder.015"] = maps(128375223920446, 129703496859412, 107575039638821, 118718672813519, "Cow_Onionnade_Cylinder.015"),
		},
	}),
	skin("Lemonade", 109831741439410, {
		["1k"] = {
			["RootPart"] = maps(131931253491745, 92464817814851, 100637943241949, 72662138227142),
		},
		["2k"] = {
			["RootPart"] = maps(138840578562980, 89794100854012, 124556930895044, 134945176226888),
		},
	}),
	skin("Pinapple", 104783086554239, {
		["1k"] = {
			["Cylinder.011"] = maps(121522085503761, 70802061713366, 100637943241949, 72662138227142, "Cow_Pinapple_Cylinder.011"),
			["Cylinder.012"] = maps(119320376934616, 101137414192309, 100637943241949, 72662138227142, "Cow_Pinapple_Cylinder.012"),
		},
		["2k"] = {
			["Cylinder.011"] = maps(138847847059782, 133991322393813, 86637783976577, 130441738130655, "Cow_Pinapple_Cylinder.011"),
			["Cylinder.012"] = maps(110235592089594, 132963448595359, 98985193244208, 138412001450340, "Cow_Pinapple_Cylinder.012"),
		},
	}),
	skin("Moolotov", 120978294802371, {
		["1k"] = {
			["Cylinder.016"] = maps(84230866593507, 70586699483540, 100637943241949, 72662138227142),
			["Cylinder.006"] = maps(91039534824876, 72335142613038, 100637943241949, 72662138227142),
		},
		["2k"] = {
			["Cylinder.016"] = maps(79682892169742, 135706905442963, 135932104785873, 137168723883568),
			["Cylinder.006"] = maps(85702342649592, 134916820303936, 92063558085496, 129104883055662),
		},
	}),
	skin("Bananarang", 122330495389058, {
		["1k"] = {
			["RootPart"] = maps(99211699291891, 128935342863513, 100637943241949, 72662138227142),
		},
		["2k"] = {
			["RootPart"] = maps(84045364009690, 111387027025832, 131156750972073, 125539577002564),
		},
	}),
}

local function byId(id: string): Skin?
	for _, entry in Skins do
		if entry.Id == id then
			return entry
		end
	end
	return nil
end

local function byGamepass(gamepassId: number): Skin?
	if gamepassId <= 0 then
		return nil
	end
	for _, entry in Skins do
		if entry.GamepassId == gamepassId then
			return entry
		end
	end
	return nil
end

local function attributeName(gun: string): string
	return `{ATTRIBUTE_PREFIX}{gun}`
end

local function forPlayer(player: Player, gun: string): Skin?
	const id = player:GetAttribute(attributeName(gun))
	if typeof(id) ~= "string" then
		return nil
	end
	return byId(id)
end

local function meshSource(name: string): MeshPart?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const folder = assets and assets:FindFirstChild(MESH_FOLDER)
	const source = folder and folder:FindFirstChild(name)
	if source and source:IsA("MeshPart") then
		return source
	end
	return nil
end

local function textureSource(skinId: string, resolution: Resolution, partName: string): SurfaceAppearance?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const root = assets and assets:FindFirstChild(TEXTURE_FOLDER)
	const skinFolder = root and root:FindFirstChild(skinId)
	const resolutionFolder = skinFolder and skinFolder:FindFirstChild(resolution)
	const template = resolutionFolder and resolutionFolder:FindFirstChild(partName)
	if template and template:IsA("SurfaceAppearance") then
		return template
	end
	return nil
end

local function swapPart(model: Instance, old: MeshPart, source: MeshPart): MeshPart
	const part = source:Clone()
	part.Name = old.Name
	part.Size = old.Size
	part.CFrame = old.CFrame
	part.Anchored = old.Anchored
	part.CanCollide = old.CanCollide
	part.CanQuery = old.CanQuery
	part.CanTouch = old.CanTouch
	part.Massless = old.Massless

	for _, child in old:GetChildren() do
		child.Parent = part
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			if descendant.Part0 == old then
				descendant.Part0 = part
			end
			if descendant.Part1 == old then
				descendant.Part1 = part
			end
		end
	end

	part.Parent = old.Parent
	old:Destroy()
	return part
end

local function apply(model: Instance, entry: Skin, resolution: Resolution?)
	const key: Resolution = resolution or "2k"
	const parts = entry.Textures[key]

	const targets: { MeshPart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("MeshPart") and parts[descendant.Name] then
			table.insert(targets, descendant)
		end
	end

	for _, target in targets do
		const textures = parts[target.Name]
		const source = if textures.Mesh then meshSource(textures.Mesh) else nil
		const part = if source then swapPart(model, target, source) else target

		const template = textureSource(entry.Id, key, target.Name)
		if template then
			const existing = part:FindFirstChildOfClass("SurfaceAppearance")
			if existing then
				existing:Destroy()
			end
			template:Clone().Parent = part
		end
	end
end

return {
	Skins = Skins,
	Categories = Categories,
	ById = byId,
	ByGamepass = byGamepass,
	AttributeName = attributeName,
	ForPlayer = forPlayer,
	Apply = apply,
}
