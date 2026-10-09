--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

const create = Vide.create
const indexes = Vide.indexes

export type Hit = { Angle: number, Alpha: number }

export type Props = {
	Hits: () -> { Hit },
	Flash: () -> number,
	LowHealth: () -> number,
}

const RED = Color3.fromHex("#D12A2A")
const RADIUS = 0.17
const ARC_WIDTH = 0.11
const ARC_HEIGHT = 0.018
const FLASH_TRANSPARENCY = 0.82
const LOW_HEALTH_TRANSPARENCY = 0.55

local function arc(hit: () -> Hit): Frame
	return create("Frame")({
		Name = "Hit",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Rotation = function()
			return hit().Angle
		end,

		create("Frame")({
			Name = "Arc",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5 - RADIUS),
			Size = UDim2.fromScale(ARC_WIDTH, ARC_HEIGHT),
			BackgroundColor3 = RED,
			BackgroundTransparency = function()
				return 1 - hit().Alpha
			end,

			create("UICorner")({
				CornerRadius = UDim.new(1, 0),
			}),

			create("UIGradient")({
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		}),
	})
end

local function edge(name: string, rotation: number, strength: () -> number, base: number): Frame
	return create("Frame")({
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = RED,
		BackgroundTransparency = function()
			return 1 - (1 - base) * strength()
		end,

		create("UIGradient")({
			Rotation = rotation,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.3, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
end

local function vignette(name: string, strength: () -> number, base: number): Frame
	return create("Frame")({
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		edge("Left", 0, strength, base),
		edge("Right", 180, strength, base),
		edge("Top", 90, strength, base),
		edge("Bottom", 270, strength, base),
	})
end

return function(props: Props): Frame
	return create("Frame")({
		Name = "DamageIndicator",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		vignette("LowHealth", props.LowHealth, LOW_HEALTH_TRANSPARENCY),
		vignette("Flash", props.Flash, FLASH_TRANSPARENCY),

		create("Frame")({
			Name = "Arcs",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,

			create("UIAspectRatioConstraint")({
				AspectRatio = 1,
			}),

			indexes(props.Hits, function(hit)
				return arc(hit)
			end),
		}),
	})
end
