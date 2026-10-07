--!strict
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type Source = "Leaderstats" | "Options" | "RobloxMenu" | "Practice"

const BLUR_SIZE = 12
const BLUR_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

const DEFAULT_FOV_DELTA = 6
const FOV_DELTAS: { [string]: number } = {
	Leaderstats = -8,
}

const MenuEffectsController = Modux.Controller("MenuEffectsController", {
	Require = {},
	Priority = 300,
})

function MenuEffectsController:Setup()
	self.Sources = {} :: { [string]: boolean }
	self.Count = 0 :: number
	self.Tween = nil :: Tween?

	const blur = Instance.new("BlurEffect")
	blur.Name = "MenuBlur"
	blur.Size = 0
	blur.Enabled = false
	self.Blur = blur :: BlurEffect
end

function MenuEffectsController:IsOpen(): boolean
	return self.Count > 0
end

function MenuEffectsController:FovDelta(): number
	const sources = self.Sources :: { [string]: boolean }
	local delta = -math.huge
	for source in sources do
		delta = math.max(delta, FOV_DELTAS[source] or DEFAULT_FOV_DELTA)
	end

	return if delta == -math.huge then 0 else delta
end

function MenuEffectsController:ApplyBlur()
	const open = self.Count > 0
	const blur = self.Blur

	const previous = self.Tween
	if previous then
		previous:Cancel()
		previous:Destroy()
		self.Tween = nil
	end

	if open then
		blur.Enabled = true
	end

	const tween = TweenService:Create(blur, BLUR_TWEEN, { Size = if open then BLUR_SIZE else 0 })
	self.Tween = tween
	tween.Completed:Connect(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed and not open then
			blur.Enabled = false
		end
	end)
	tween:Play()
end

function MenuEffectsController:Set(source: Source, on: boolean)
	if (self.Sources[source] == true) == on then
		return
	end

	self.Sources[source] = if on then true else nil
	self.Count += if on then 1 else -1
	self:ApplyBlur()
end

function MenuEffectsController:Open(source: Source)
	self:Set(source, true)
end

function MenuEffectsController:Close(source: Source)
	self:Set(source, false)
end

MenuEffectsController:OnInit(function(self)
	self:Setup()
	self.Blur.Parent = Lighting
end)

MenuEffectsController:OnStart(function(self)
	GuiService.MenuOpened:Connect(function()
		self:Open("RobloxMenu")
	end)

	GuiService.MenuClosed:Connect(function()
		self:Close("RobloxMenu")
	end)
end)

return MenuEffectsController
