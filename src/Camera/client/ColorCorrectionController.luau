--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Lighting = game:GetService("Lighting")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const MAX_SATURATION = 0.5
const MIN_SATURATION = -1.5

const ColorCorrectionController = Modux.Controller("ColorCorrectionController", { Priority = 500 })

function ColorCorrectionController:Setup()
	self.Effect = Instance.new("ColorCorrectionEffect") :: ColorCorrectionEffect
end

function ColorCorrectionController:SetSaturation(value: number)
	self.Effect.Saturation = math.clamp(value, MIN_SATURATION, MAX_SATURATION)
end

ColorCorrectionController:OnInit(function(self)
	self:Setup()
	self.Effect.Parent = Lighting
end)

return ColorCorrectionController
