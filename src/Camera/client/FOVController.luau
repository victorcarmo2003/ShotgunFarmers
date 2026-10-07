--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type FOVState = "Run" | "Idle"

const TWEEN_INFO = TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
const MENU_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
const SCOPE_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

const RUN_FOV_DELTA = 3
const AIM_FOV_DELTA = 1

const TICK_RATE = 60

const FOVController = Modux.Controller("FOVController", {
	Require = {
		"ArmsController",
		"GameStateController",
		"MenuEffectsController",
		"MovementController",
		"OptionsController",
		"ScopeController",
	},
	Priority = 420,
})

function FOVController:Setup()
	self.Tween = nil :: Tween?

	self.Style = nil :: FOVState?
	self.Aiming = nil :: boolean?
	self.BaseFov = nil :: number?
	self.MenuDelta = nil :: number?
	self.ScopeFov = nil :: number?
end

function FOVController:TargetFov(style: FOVState, aiming: boolean, menuDelta: number, scopeFov: number?): number
	if scopeFov then
		return scopeFov + menuDelta
	end

	const idle = self.Dependencies.OptionsController:Get("Fov")
	const base = if style == "Run" then idle + RUN_FOV_DELTA else idle
	const aimed = if aiming then base - AIM_FOV_DELTA else base
	return aimed + menuDelta
end

function FOVController:ApplyFov(
	style: FOVState,
	aiming: boolean,
	menuDelta: number,
	scopeFov: number?,
	info: TweenInfo
)
	const camera = workspace.CurrentCamera
	if not camera then
		return
	end

	const previous = self.Tween
	if previous then
		previous:Cancel()
		previous:Destroy()
	end

	const tween = TweenService:Create(camera, info, { FieldOfView = self:TargetFov(style, aiming, menuDelta, scopeFov) })
	self.Tween = tween
	tween:Play()
end

function FOVController:Step()
	if not self.Dependencies.GameStateController:Can("FirstPerson") then
		return
	end

	const style: FOVState = if self.Dependencies.MovementController.IsMoving() then "Run" else "Idle"
	const aiming = self.Dependencies.ArmsController.IsAiming()
	const baseFov = self.Dependencies.OptionsController:Get("Fov")
	const menuDelta = self.Dependencies.MenuEffectsController:FovDelta()
	const scopeFov = self.Dependencies.ScopeController:Fov()
	if
		style == self.Style
		and aiming == self.Aiming
		and baseFov == self.BaseFov
		and menuDelta == self.MenuDelta
		and scopeFov == self.ScopeFov
	then
		return
	end

	const info = if scopeFov ~= self.ScopeFov
		then SCOPE_TWEEN_INFO
	elseif menuDelta ~= self.MenuDelta and self.MenuDelta ~= nil then MENU_TWEEN_INFO
	else TWEEN_INFO
	self.Style = style
	self.Aiming = aiming
	self.BaseFov = baseFov
	self.MenuDelta = menuDelta
	self.ScopeFov = scopeFov
	self:ApplyFov(style, aiming, menuDelta, scopeFov, info)
end

FOVController:OnTick(function(self)
	self:Step()
end, TICK_RATE)

FOVController:OnInit(function(self)
	self:Setup()
end)

return FOVController
