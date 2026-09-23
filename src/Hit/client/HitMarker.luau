--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)

const create = Vide.create
const effect = Vide.effect

const MARK_LENGTH = 24
const MARK_THICKNESS = 3
const FADE_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

export type Props = {
	Trigger: () -> number,
	Position: UDim2?,
}

local function mark(name: string, rotation: number): Frame
	return create("Frame")({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(MARK_LENGTH, MARK_THICKNESS),
		Rotation = rotation,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
	})
end

return function(props: Props): Frame
	const marks = { mark("Mark1", 45), mark("Mark2", -45) }
	const running: { [Frame]: Tween } = {}

	local previous: number? = nil

	effect(function()
		const current = props.Trigger()
		const fired = previous ~= nil and current ~= previous
		previous = current

		if not fired then
			return
		end

		for _, frame in marks do
			const playing = running[frame]
			if playing then
				playing:Cancel()
				playing:Destroy()
			end

			frame.BackgroundTransparency = 0
			const tween = TweenService:Create(frame, FADE_TWEEN, { BackgroundTransparency = 1 })
			running[frame] = tween
			tween:Play()
		end
	end)

	return create("Frame")({
		Name = "HitMarker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,

		marks,
	})
end
