--!strict
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local StarterPlayer = game:GetService "StarterPlayer"
local Vide = require(ReplicatedStorage.Packages.Vide)
local ScreenKit = require(StarterPlayer.StarterPlayerScripts.client.Interface.ScreenKit)

const create = Vide.create

const at = ScreenKit.at
const inside = ScreenKit.inside
const label = ScreenKit.label

export type Mode = "QuickPlay" | "FFA" | "TDM" | "Practice"

export type Props = {
	Visible: (() -> boolean)?,
	OnSelectMode: ((mode: Mode) -> ())?,
	OnJoinRoom: (() -> ())?,
	OnCreateRoom: (() -> ())?,
	OnClose: (() -> ())?,
	Status: (() -> string)?,
}

const MODES: { { Mode: Mode, Label: string, X: number } } = {
	{ Mode = "QuickPlay", Label = "FAST", X = 124 },
	{ Mode = "FFA", Label = "30 PLAYERS", X = 349 },
	{ Mode = "TDM", Label = "TEAM-DEATHMATCH", X = 574 },
	{ Mode = "Practice", Label = "PRACTICE", X = 799 },
}

const MODE_IMAGES: { [Mode]: string } = {
	QuickPlay = "rbxassetid://90339424446992",
	FFA = "rbxassetid://83633686102846",
	TDM = "rbxassetid://96105075737080",
	Practice = "rbxassetid://70939426168058",
}

const MODE_COLORS: { [Mode]: Color3 } = {
	QuickPlay = Color3.new(0.352941, 0.733333, 0),
	FFA = Color3.fromHex "#FF9D00",
	TDM = Color3.new(0, 0.352941, 0.960784),
	Practice = Color3.new(0.839216, 0.031373, 0.015686),
}

const CARD_W = 192
const CARD_H = 253

const MODE_SEEDS: { [Mode]: number } = {
	QuickPlay = 7,
	FFA = 23,
	TDM = 41,
	Practice = 59,
}

local function paintRandom(seed: number): (number, number) -> number
	local state = seed * 9301 + 49297
	return function(min: number, max: number): number
		state = (state * 9301 + 49297) % 233280
		return min + (state / 233280) * (max - min)
	end
end

local function blob(
	name: string,
	cx: number,
	cy: number,
	w: number,
	h: number,
	rotation: number,
	color: Color3,
	transparency: number,
	round: number
): Frame
	return create "Frame" {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = inside(cx, cy, CARD_W, CARD_H),
		Size = inside(w, h, CARD_W, CARD_H),
		Rotation = rotation,
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,

		create "UICorner" {
			CornerRadius = UDim.new(round, 0),
		},
	}
end

local function inkSplash(mode: Mode): Frame
	const base = MODE_COLORS[mode]
	const dark = base:Lerp(ScreenKit.Colors.Black, 0.4)
	const darker = base:Lerp(ScreenKit.Colors.Black, 0.6)
	const light = base:Lerp(ScreenKit.Colors.White, 0.35)
	const rand = paintRandom(MODE_SEEDS[mode])
	const layers: { Instance } = {}

	for index = 1, 4 do
		const y = (index - 0.5) * (CARD_H / 4) + rand(-14, 14)
		table.insert(
			layers,
			blob(
				`Stroke{index}`,
				rand(70, 122),
				y,
				rand(230, 300),
				rand(14, 34),
				rand(-28, 28),
				if index % 2 == 0 then light else dark,
				rand(0.72, 0.86),
				rand(0.15, 0.45)
			)
		)
	end

	for index = 1, 2 do
		const cx = if index == 1 then rand(10, 50) else rand(140, 185)
		const cy = if index == 1 then rand(20, 90) else rand(170, 245)
		table.insert(layers, blob(`Pool{index}`, cx, cy, rand(90, 130), rand(70, 110), rand(0, 180), darker, rand(0.5, 0.65), 0.5))
		table.insert(layers, blob(`Core{index}`, cx + rand(-10, 10), cy + rand(-10, 10), rand(50, 80), rand(40, 70), rand(0, 180), dark, rand(0.4, 0.55), 0.5))
		for arm = 1, 3 do
			table.insert(
				layers,
				blob(`Arm{index}_{arm}`, cx, cy, rand(110, 170), rand(6, 14), rand(0, 180), darker, rand(0.55, 0.7), 0.5)
			)
		end
	end

	for index = 1, 18 do
		const size = rand(3, 13)
		table.insert(
			layers,
			blob(
				`Drop{index}`,
				rand(4, CARD_W - 4),
				rand(4, CARD_H - 4),
				size,
				size * rand(0.8, 1.3),
				rand(0, 180),
				if index % 3 == 0 then light else darker,
				rand(0.35, 0.6),
				0.5
			)
		)
	end

	for index = 1, 6 do
		const side = index % 2 == 0
		table.insert(
			layers,
			blob(
				`Edge{index}`,
				if side then rand(0, 8) else rand(CARD_W - 8, CARD_W),
				rand(10, CARD_H - 10),
				rand(10, 22),
				rand(14, 40),
				rand(-20, 20),
				darker,
				rand(0.3, 0.5),
				0.4
			)
		)
	end

	return create "Frame" {
		Name = "Ink",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 1,

		create "UIGradient" {
			Transparency = NumberSequence.new(0),
		},

		layers,

		create "Frame" {
			Name = "Shade",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = ScreenKit.Colors.Black,
			BorderSizePixel = 0,

			create "UIGradient" {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.6, 0.9),
					NumberSequenceKeypoint.new(1, 0.55),
				}),
			},
		},
	}
end

local function modeCard(props: Props, mode: Mode, text: string, x: number): Frame
	return ScreenKit.pressable {
		Name = mode,
		Color = MODE_COLORS[mode],
		Position = at(x, 132),
		Size = at(192, 253),
		OnActivated = function()
			if props.OnSelectMode then
				props.OnSelectMode(mode)
			end
		end,
		Children = {
			inkSplash(mode),

			create "Frame" {
				Name = "Preview",
				Position = inside(15, 15, 192, 253),
				Size = inside(162, 185, 192, 253),
				BackgroundColor3 = ScreenKit.Colors.Black,
				BackgroundTransparency = ScreenKit.DARK_TRANSPARENCY,
				ClipsDescendants = true,

				create "ImageLabel" {
					Name = "Cover",
					Position = UDim2.fromScale(0, 0),
					Size = inside(162, 243, 162, 185),
					BackgroundTransparency = 1,
					Image = MODE_IMAGES[mode],
					ScaleType = Enum.ScaleType.Stretch,
				},
			},

			create "Frame" {
				Name = "Title",
				Position = inside(0, 208, 192, 253),
				Size = inside(192, 36, 192, 253),
				BackgroundTransparency = 1,

				label(text, 36, 36),-- label("PLAY", 36, 36), 
			},
		},
	}
end

local function wideButton(name: string, text: string, y: number, onActivated: (() -> ())?): Frame
	return ScreenKit.pressable {
		Name = name,
		Position = at(466, y),
		Size = at(190, 43),
		OnActivated = onActivated,
		Children = { label(text, 36, 43) },
	}
end

return function(props: Props): Frame
	const cards: { Instance } = {}
	for _, entry in MODES do
		table.insert(cards, modeCard(props, entry.Mode, entry.Label, entry.X))
	end

	return ScreenKit.screen {
		Name = "GameSelectionScreen",
		Visible = props.Visible,
		Children = {
			ScreenKit.panel(),
			ScreenKit.header(function()
				const status = if props.Status then props.Status() else ""
				return if status ~= "" then status else "SELECTION"
			end),
			cards,
			wideButton("JoinRoom", "JOIN ROOM", 406, props.OnJoinRoom),
			wideButton("CreateRoom", "CREATE ROOM", 466, props.OnCreateRoom),
			ScreenKit.returnButton(481, props.OnClose),
		},
	}
end
