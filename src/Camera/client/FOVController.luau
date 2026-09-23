--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type FOVState = "Run" | "Idle"

const TWEEN_INFO = TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

const RUN_FOV = 73
const IDLE_FOV = 70
const AIM_FOV_DELTA = 1

const TICK_RATE = 60

const FOVController = Modux.Controller("FOVController", {
	Require = { "ArmsController", "MovementController" },
	Priority = 420,
})

function FOVController:Setup()
	self.Tween = nil :: Tween?

	self.Style = nil :: FOVState?
	self.Aiming = nil :: boolean?
end

function FOVController:TargetFov(style: FOVState, aiming: boolean): number
	const base = if style == "Run" then RUN_FOV else IDLE_FOV
	return if aiming then base - AIM_FOV_DELTA else base
end

function FOVController:ApplyFov(style: FOVState, aiming: boolean)
	const camera = workspace.CurrentCamera
	if not camera then
		return
	end

	const previous = self.Tween
	if previous then
		previous:Cancel()
		previous:Destroy()
	end

	const tween = TweenService:Create(camera, TWEEN_INFO, { FieldOfView = self:TargetFov(style, aiming) })
	self.Tween = tween
	tween:Play()
end

function FOVController:Step()
	const style: FOVState = if self.Dependencies.MovementController.IsMoving() then "Run" else "Idle"
	const aiming = self.Dependencies.ArmsController.IsAiming()
	if style == self.Style and aiming == self.Aiming then
		return
	end

	self.Style = style
	self.Aiming = aiming
	self:ApplyFov(style, aiming)
end

FOVController:OnTick(function(self)
	self:Step()
end, TICK_RATE)

FOVController:OnInit(function(self)
	self:Setup()
end)

return FOVController
