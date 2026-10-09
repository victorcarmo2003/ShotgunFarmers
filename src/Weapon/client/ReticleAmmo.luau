--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CreateRaw = require(ReplicatedStorage.shared.Interface.CreateRaw)
local Fonts = require(ReplicatedStorage.shared.Interface.Fonts)
local Vide = require(ReplicatedStorage.Packages.Vide)

const create = Vide.create
const derive = Vide.derive
const source = Vide.source
const effect = Vide.effect
const cleanup = Vide.cleanup
const untrack = Vide.untrack

export type Props = {
	Ammo: () -> number,
	MaxAmmo: () -> number,
	Visible: () -> boolean,
	Scale: (() -> number)?,
}

const OFFSET = 40
const AMMO_TEXT = 26
const AMMO_MIN = 16
const STATUS_TEXT = 13
const STATUS_MIN = 11
const LOW_RATIO = 0.25
const BLINK_HZ = 3
const TEXT_COLOR = Color3.new(1, 1, 1)
const DANGER_COLOR = Color3.fromRGB(255, 70, 70)

return function(props: Props): Frame
	const scale = props.Scale or function(): number
		return 1
	end

	const empty = derive(function(): boolean
		return props.Ammo() <= 0
	end)
	const low = derive(function(): boolean
		const max = props.MaxAmmo()
		return not empty() and max > 0 and props.Ammo() / max <= LOW_RATIO
	end)

	const blink = source(false)
	effect(function()
		if empty() and props.Visible() then
			const connection = RunService.Heartbeat:Connect(function()
				const on = (os.clock() * BLINK_HZ) % 1 < 0.5
				if blink() ~= on then
					blink(on)
				end
			end)
			cleanup(function()
				connection:Disconnect()
			end)
		else
			untrack(function()
				blink(false)
			end)
		end
	end)

	const px = function(size: number, floor: number): () -> number
		return function(): number
			return math.max(math.round(size * scale()), floor)
		end
	end
	const color = function(): Color3
		return if empty() or low() then DANGER_COLOR else TEXT_COLOR
	end
	const transparency = function(): number
		return if blink() then 0.7 else 0
	end
	const status = function(): string
		if empty() then
			return "EMPTY"
		elseif low() then
			return "LOW"
		end
		return ""
	end

	return create("Frame")({
		Name = "ReticleAmmo",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = function(): UDim2
			return UDim2.new(0.5, math.round(OFFSET * scale()), 0.5, 0)
		end,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Visible = props.Visible,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		create("TextLabel")({
			Name = "Ammo",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = Fonts.FredokaOne,
			TextSize = px(AMMO_TEXT, AMMO_MIN),
			TextColor3 = color,
			TextTransparency = transparency,
			Text = function(): string
				return tostring(math.max(math.floor(props.Ammo()), 0))
			end,

			CreateRaw("UIStroke")({
				Color = Color3.new(0, 0, 0),
				Thickness = 1.5,
				Transparency = transparency,
			}),
		}),

		create("TextLabel")({
			Name = "Status",
			LayoutOrder = 2,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = Fonts.FredokaOne,
			TextSize = px(STATUS_TEXT, STATUS_MIN),
			TextColor3 = DANGER_COLOR,
			Text = status,
			Visible = function(): boolean
				return status() ~= ""
			end,

			CreateRaw("UIStroke")({
				Color = Color3.new(0, 0, 0),
				Thickness = 1,
			}),
		}),
	})
end
