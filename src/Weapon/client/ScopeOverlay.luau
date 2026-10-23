--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScopeSettings = require(ReplicatedStorage.shared.Weapon.ScopeSettings)
local Vide = require(ReplicatedStorage.Packages.Vide)
local ScopeReticle = require(script.Parent.ScopeReticle)

const create = Vide.create

const LINE_THICKNESS = 4
const RETICLE_TRANSPARENCY = 0.15

export type Props = {
	Visible: (() -> boolean)?,
	Name: string?,
	Fraction: (() -> number)?,
	Center: (() -> Vector2)?,
	Alpha: (() -> number)?,
	Rotation: (() -> number)?,
	HousingColor: (() -> Color3)?,
	Thickness: (() -> number)?,
	DotSize: (() -> number)?,
}

local function new(props: Props): Frame
	const fraction = props.Fraction or function()
		return ScopeSettings.CircleFraction
	end
	const center = props.Center or function()
		return Vector2.new(0.5, 0.5)
	end
	const alpha = props.Alpha or function()
		return 1
	end

	const rotation = props.Rotation or function()
		return 0
	end
	const housing = props.HousingColor or function()
		return ScopeSettings.DefaultHousingColor
	end
	const thickness = props.Thickness or function()
		return LINE_THICKNESS
	end

	const position = function()
		const value = center()
		return UDim2.fromScale(value.X, value.Y)
	end
	const reticleTransparency = function()
		return 1 - alpha() * (1 - RETICLE_TRANSPARENCY)
	end

	return create("Frame")({
		Name = props.Name or "ScopeOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = props.Visible,

		create("ImageLabel")({
			Name = "Halo",
			ZIndex = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = position,
			Rotation = rotation,
			Size = function()
				const scale = fraction() / ScopeSettings.RingInnerRatio * ScopeSettings.HaloScale
				return UDim2.fromScale(scale, scale)
			end,
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = ScopeSettings.HaloImage,
			ImageColor3 = housing,
			ImageTransparency = function()
				return 1 - alpha()
			end,
			ScaleType = Enum.ScaleType.Stretch,
		}),

		create("ImageLabel")({
			Name = "Ring",
			ZIndex = 2,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = position,
			Rotation = rotation,
			Size = function()
				const scale = fraction() / ScopeSettings.RingInnerRatio
				return UDim2.fromScale(scale, scale)
			end,
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = ScopeSettings.RingImage,
			ImageTransparency = function()
				return 1 - alpha()
			end,
			ScaleType = Enum.ScaleType.Stretch,
		}),

		create("Frame")({
			Name = "Reticle",
			ZIndex = 3,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = position,
			Rotation = rotation,
			Size = function()
				const scale = fraction()
				return UDim2.fromScale(scale, scale)
			end,
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundTransparency = 1,

			ScopeReticle({
				Thickness = thickness,
				Transparency = reticleTransparency,
				ZIndex = 3,
			}),
		}),
	})
end

return {
	new = new,
}
