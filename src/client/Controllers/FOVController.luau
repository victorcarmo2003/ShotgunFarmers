local TweenService = game:GetService("TweenService")
local Modux = require(game.ReplicatedStorage.Shared.Modux)

local FOVController = Modux.Controller("FOVController"):Import("ArmsController")
type Self = typeof(FOVController)

export type FOVState = "Run" | "Idle"
local TInfo = TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

const FOVList = {
	Run = 73,
	Idle = 70,
}

const AIM_FOV_DELTA = 1

local function compareVector3(v0: Vector3, v1: Vector3)
	local v0X, v0Y, v0Z = v0.X, v0.Y, v0.Z
	local v1X, v1Y, v1Z = v1.X, v1.Y, v1.Z
	if v0X ~= v1X or v0Y ~= v1Y or v0Z ~= v1Z then
		return true
	end
	return false
end

FOVController.ApplyFov = function(self: Self, Style: FOVState)
	local camera = workspace.CurrentCamera
	if self.TweenCamera then
		self.TweenCamera:Pause()
		self.TweenCamera:Destroy()
	end
	local targetFov = FOVList[Style]
	if self.ArmsController.IsAiming then
		targetFov -= AIM_FOV_DELTA
	end
	self.TweenCamera = TweenService:Create(camera, TInfo, { FieldOfView = targetFov }) :: Tween
	self.TweenCamera:Play()
end

FOVController:OnTick(function(self)
	if not self.LocalHumanoid then
		return
	end

	local moveDirection = self.LocalHumanoid.MoveDirection
	if compareVector3(moveDirection, Vector3.new(0, 0, 0)) then
		FOVController:ApplyFov("Run")
	else
		FOVController:ApplyFov("Idle")
	end
end, Modux.TickRate.Hz60)

return FOVController
