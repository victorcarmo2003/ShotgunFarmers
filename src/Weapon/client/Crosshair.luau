--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

const create = Vide.create
const derive = Vide.derive
const spring = Vide.spring

const MARK_LENGTH = 10
const MARK_THICKNESS = 3

const MIN_GAP = 6
const MAX_GAP = 16

const GAP_SPRING_PERIOD = 0.25

export type Props = {
	AimType: () -> string,
	SpreadRatio: () -> number,
	IsAiming: () -> boolean,
	Name: string?,
}

local function spreadMark(gap: () -> number, direction: "Top" | "Bottom" | "Left" | "Right"): Frame
	const isVertical = direction == "Top" or direction == "Bottom"
	const sign = if direction == "Top" or direction == "Left" then -1 else 1

	return create("Frame")({
		Name = direction,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = function()
			const offset = gap() * sign
			return if isVertical then UDim2.fromOffset(0, offset) else UDim2.fromOffset(offset, 0)
		end,
		Size = if isVertical
			then UDim2.fromOffset(MARK_THICKNESS, MARK_LENGTH)
			else UDim2.fromOffset(MARK_LENGTH, MARK_THICKNESS),
		BackgroundColor3 = Color3.new(1, 1, 1),

		create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
	})
end

return function(props: Props): Frame
	const gap = spring(function()
		return MIN_GAP + (MAX_GAP - MIN_GAP) * props.SpreadRatio()
	end, GAP_SPRING_PERIOD, 1)

	const isSpreadable = derive(function()
		return props.AimType() == "Spread"
	end)

	return create("Frame")({
		Name = props.Name or "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Visible = function()
			return not props.IsAiming()
		end,

		create("Frame")({
			Name = "SpreadMarks",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			Visible = isSpreadable,

			spreadMark(gap, "Top"),
			spreadMark(gap, "Bottom"),
			spreadMark(gap, "Left"),
			spreadMark(gap, "Right"),
		}),

		create("Frame")({
			Name = "Plus",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			Visible = function()
				return not isSpreadable()
			end,

			create("Frame")({
				Name = "Horizontal",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(MARK_LENGTH * 2, MARK_THICKNESS),
				BackgroundColor3 = Color3.new(1, 1, 1),
			}),

			create("Frame")({
				Name = "Vertical",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(MARK_THICKNESS, MARK_LENGTH * 2),
				BackgroundColor3 = Color3.new(1, 1, 1),
			}),
		}),
	})
end
