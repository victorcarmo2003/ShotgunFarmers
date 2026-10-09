--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Lighting = game:GetService("Lighting")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const MAX_SATURATION = 0.5
const MIN_SATURATION = -1.5
const GRAY_SATURATION = -1

const ColorCorrectionController = Modux.Controller("ColorCorrectionController", { Priority = 500 })

function ColorCorrectionController:Setup()
	self.Effect = Instance.new("ColorCorrectionEffect") :: ColorCorrectionEffect
	self.BaseSaturation = 0 :: number
	self.Gray = 0 :: number
end

function ColorCorrectionController:Apply()
	const base = math.clamp(self.BaseSaturation, MIN_SATURATION, MAX_SATURATION)
	self.Effect.Saturation = base + (math.min(base, GRAY_SATURATION) - base) * self.Gray
end

function ColorCorrectionController:SetSaturation(value: number)
	self.BaseSaturation = value
	self:Apply()
end

function ColorCorrectionController:SetGray(amount: number)
	const clamped = math.clamp(amount, 0, 1)
	if clamped == self.Gray then
		return
	end
	self.Gray = clamped
	self:Apply()
end

ColorCorrectionController:OnInit(function(self)
	self:Setup()
	self.Effect.Parent = Lighting
end)

return ColorCorrectionController
