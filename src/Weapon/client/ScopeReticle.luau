--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fonts = require(ReplicatedStorage.shared.Interface.Fonts)
local Vide = require(ReplicatedStorage.Packages.Vide)

const create = Vide.create

export type Props = {
	Thickness: (() -> number)?,
	Transparency: (() -> number)?,
	Color: (() -> Color3)?,
	Accent: (() -> Color3)?,
	ZIndex: number?,
}

const CENTER_GAP = 0.014
const INNER_REACH = 0.3
const OUTER_REACH = 0.5
const THIN_RATIO = 0.5
const POST_RATIO = 1.5
const DOT_RATIO = 1.6
const TICK_STEP = 0.05
const TICK_COUNT = 5
const TICK_MINOR = 0.016
const TICK_MAJOR = 0.03
const LADDER_WIDTH = 0.07
const LADDER_SHRINK = 0.009
const LABEL_SIZE = 0.026
const LABEL_GAP = 0.012
const DEFAULT_COLOR = Color3.fromRGB(12, 12, 14)
const DEFAULT_ACCENT = Color3.fromRGB(255, 55, 45)

type Axis = "Horizontal" | "Vertical"

return function(props: Props): Frame
	const thickness = props.Thickness or function(): number
		return 4
	end
	const transparency = props.Transparency or function(): number
		return 0
	end
	const color = props.Color or function(): Color3
		return DEFAULT_COLOR
	end
	const accent = props.Accent or function(): Color3
		return DEFAULT_ACCENT
	end
	const zIndex = props.ZIndex or 3

	const thin = function(): number
		return math.max(1, math.round(thickness() * THIN_RATIO))
	end
	const post = function(): number
		return math.max(2, math.round(thickness() * POST_RATIO))
	end

	const children: { Instance } = {}

	local function bar(name: string, axis: Axis, x: number, y: number, length: number, width: () -> number)
		table.insert(
			children,
			create("Frame")({
				Name = name,
				ZIndex = zIndex,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(x, y),
				Size = function(): UDim2
					return if axis == "Horizontal"
						then UDim2.new(length, 0, 0, width())
						else UDim2.new(0, width(), length, 0)
				end,
				BackgroundColor3 = color,
				BackgroundTransparency = transparency,
				BorderSizePixel = 0,
			})
		)
	end

	const thinLength = INNER_REACH - CENTER_GAP
	const thinOffset = (INNER_REACH + CENTER_GAP) / 2
	bar("ThinLeft", "Horizontal", 0.5 - thinOffset, 0.5, thinLength, thin)
	bar("ThinRight", "Horizontal", 0.5 + thinOffset, 0.5, thinLength, thin)
	bar("ThinTop", "Vertical", 0.5, 0.5 - thinOffset, thinLength, thin)
	bar("ThinBottom", "Vertical", 0.5, 0.5 + thinOffset, thinLength, thin)

	const postLength = OUTER_REACH - INNER_REACH
	const postOffset = (OUTER_REACH + INNER_REACH) / 2
	bar("PostLeft", "Horizontal", 0.5 - postOffset, 0.5, postLength, post)
	bar("PostRight", "Horizontal", 0.5 + postOffset, 0.5, postLength, post)
	bar("PostTop", "Vertical", 0.5, 0.5 - postOffset, postLength, post)
	bar("PostBottom", "Vertical", 0.5, 0.5 + postOffset, postLength, post)

	for index = 1, TICK_COUNT do
		const offset = index * TICK_STEP
		const size = if index % 2 == 0 then TICK_MAJOR else TICK_MINOR
		bar(`TickLeft{index}`, "Vertical", 0.5 - offset, 0.5, size, thin)
		bar(`TickRight{index}`, "Vertical", 0.5 + offset, 0.5, size, thin)
		bar(`TickTop{index}`, "Horizontal", 0.5, 0.5 - offset, size, thin)

		const width = LADDER_WIDTH - (index - 1) * LADDER_SHRINK
		bar(`Ladder{index}`, "Horizontal", 0.5, 0.5 + offset, width, thin)

		if index % 2 == 0 then
			table.insert(
				children,
				create("TextLabel")({
					Name = `LadderLabel{index}`,
					ZIndex = zIndex,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0.5 + width / 2 + LABEL_GAP, 0.5 + offset),
					Size = UDim2.fromScale(LABEL_SIZE * 2, LABEL_SIZE),
					BackgroundTransparency = 1,
					FontFace = Fonts.FredokaOne,
					Text = tostring(index * 100),
					TextColor3 = color,
					TextTransparency = transparency,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
			)
		end
	end

	table.insert(
		children,
		create("Frame")({
			Name = "Dot",
			ZIndex = zIndex + 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = 45,
			Size = function(): UDim2
				const size = math.max(2, math.round(thickness() * DOT_RATIO))
				return UDim2.fromOffset(size, size)
			end,
			BackgroundColor3 = accent,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
		})
	)

	return create("Frame")({
		Name = "ScopeReticle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		children,
	})
end
