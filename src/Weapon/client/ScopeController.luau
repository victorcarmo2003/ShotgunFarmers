--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local ScopeSettings = require(ReplicatedStorage.shared.Weapon.ScopeSettings)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local ScopeCharacters = require(StarterPlayer.StarterPlayerScripts.client.Weapon.ScopeCharacters)
local ScopeLens = require(StarterPlayer.StarterPlayerScripts.client.Weapon.ScopeLens)
local ScopeOverlay = require(StarterPlayer.StarterPlayerScripts.client.Weapon.ScopeOverlay)
local ScopeView = require(StarterPlayer.StarterPlayerScripts.client.Weapon.ScopeView)
local ScopeViewmodel = require(StarterPlayer.StarterPlayerScripts.client.Weapon.ScopeViewmodel)

const create = Vide.create

const TICK_RATE = 60
const CENTER = Vector2.new(0.5, 0.5)

local warned = false

local function stepSpring(position: number, velocity: number, deltaTime: number, frequency: number, damping: number): (number, number)
	const omega = 2 * math.pi * frequency
	const zeta = math.min(damping, 0.999)
	const damped = omega * math.sqrt(1 - zeta * zeta)
	const decay = math.exp(-zeta * omega * deltaTime)
	const cosine = math.cos(damped * deltaTime)
	const sine = math.sin(damped * deltaTime)
	const ratio = zeta * omega / damped
	const nextPosition = decay * (position * (cosine + ratio * sine) + velocity * sine / damped)
	const nextVelocity = decay * (velocity * (cosine - ratio * sine) - position * omega * omega / damped * sine)
	return nextPosition, nextVelocity
end

local function warnLens(name: string)
	if warned then
		return
	end
	warned = true
	warn(`[ScopeController] lente "{name}" nao encontrada no viewmodel da arma; PiP desativado (modo mira segue funcionando)`)
end

local function stripMapClone(root: Instance)
	for _, descendant in root:GetDescendants() do
		if
			descendant:IsA("LuaSourceContainer")
			or descendant:IsA("Sound")
			or descendant:IsA("ParticleEmitter")
			or descendant:IsA("BillboardGui")
			or descendant:IsA("SurfaceGui")
		then
			descendant:Destroy()
		end
	end
end

const ScopeController = Modux.Controller("ScopeController", {
	Require = { "ArmsController", "HitController", "WeaponController", "OptionsController" },
	Priority = 400,
})

function ScopeController:Setup()
	self.Active = Vide.source(false) :: Vide.Source<boolean>
	self.OverlayFraction = Vide.source(ScopeSettings.CircleFraction) :: Vide.Source<number>
	self.OverlayCenter = Vide.source(CENTER) :: Vide.Source<Vector2>
	self.OverlayAlpha = Vide.source(0) :: Vide.Source<number>
	self.OverlayHousing = Vide.source(ScopeSettings.DefaultHousingColor) :: Vide.Source<Color3>
	self.View = nil :: ScopeView.ScopeView?
	self.Lens = nil :: ScopeLens.ScopeLens?
	self.Characters = {} :: { ScopeCharacters.ScopeCharacters }
	self.LensCharacters = nil :: ScopeCharacters.ScopeCharacters?
	self.Mirrors = {} :: { ScopeViewmodel.ScopeViewmodel }
	self.Unmount = nil :: (() -> ())?
	self.Model = nil :: Model?
	self.MapReady = false :: boolean
	self.PreloadToken = 0 :: number
	self.Rendering = false :: boolean
	self.Raw = 0 :: number
	self.ViewShown = false :: boolean
	self.MirrorOn = false :: boolean
	self.LensAttached = false :: boolean
	self.KickX = 0 :: number
	self.KickY = 0 :: number
	self.KickRoll = 0 :: number
	self.KickVelX = 0 :: number
	self.KickVelY = 0 :: number
	self.KickVelRoll = 0 :: number
	self.Kicking = false :: boolean
	self.KickApplied = false :: boolean
	self.OverlayRotation = Vide.source(0) :: Vide.Source<number>
end

function ScopeController:Kick(strength: number?)
	if not self.Rendering then
		return
	end

	const gunData = self.Dependencies.WeaponController:GunData()
	if not gunData or not gunData.Scope then
		return
	end

	const scale = strength or 1
	const side = math.random() * 2 - 1
	const limit = ScopeSettings.KickMax
	self.KickY = math.clamp(self.KickY - ScopeSettings.KickUp * scale, -ScopeSettings.KickUp * limit, ScopeSettings.KickUp * limit)
	self.KickX = math.clamp(self.KickX + side * ScopeSettings.KickSide * scale, -ScopeSettings.KickSide * limit, ScopeSettings.KickSide * limit)
	self.KickRoll = math.clamp(self.KickRoll + side * ScopeSettings.KickRoll * scale, -ScopeSettings.KickRoll * limit, ScopeSettings.KickRoll * limit)
	self.Kicking = true
end

function ScopeController:ResetKick()
	self.KickX = 0
	self.KickY = 0
	self.KickRoll = 0
	self.KickVelX = 0
	self.KickVelY = 0
	self.KickVelRoll = 0
	self.Kicking = false
end

function ScopeController:StepKick(deltaTime: number)
	const step = math.min(deltaTime, 1 / 20)
	const frequency = ScopeSettings.KickFrequency
	const damping = ScopeSettings.KickDamping
	self.KickX, self.KickVelX = stepSpring(self.KickX, self.KickVelX, step, frequency, damping)
	self.KickY, self.KickVelY = stepSpring(self.KickY, self.KickVelY, step, frequency, damping)
	self.KickRoll, self.KickVelRoll = stepSpring(self.KickRoll, self.KickVelRoll, step, frequency, damping)

	const epsilon = ScopeSettings.KickEpsilon
	const settled = math.abs(self.KickX) < epsilon
		and math.abs(self.KickY) < epsilon
		and math.abs(self.KickVelX) < epsilon
		and math.abs(self.KickVelY) < epsilon
		and math.abs(self.KickRoll) < epsilon * 100
		and math.abs(self.KickVelRoll) < epsilon * 100
	if settled then
		self:ResetKick()
	end
end

function ScopeController:Fov(): number?
	if not self.Dependencies.ArmsController.IsAiming() then
		return nil
	end

	const gunData = self.Dependencies.WeaponController:GunData()
	const scope = if gunData then gunData.Scope else nil
	return if scope then scope.Fov else nil
end

function ScopeController:HeldModel(): Model?
	const gunData = self.Dependencies.WeaponController:GunData()
	if not gunData or not gunData.Scope then
		return nil
	end

	const model = self.Dependencies.ArmsController.WeaponModel
	if model and model.Parent then
		return model
	end
	return nil
end

function ScopeController:ReleaseMap()
	self:StopRendering()

	for _, characters in self.Characters do
		characters.Destroy()
	end
	table.clear(self.Characters)
	if self.LensCharacters then
		self.LensCharacters.Destroy()
		self.LensCharacters = nil
	end
	for _, mirror in self.Mirrors do
		mirror.Destroy()
	end
	table.clear(self.Mirrors)

	const view = self.View
	if view then
		for _, worldModel in view.WorldModels do
			worldModel:ClearAllChildren()
		end
	end
	const lens = self.Lens
	if lens then
		lens.WorldModel:ClearAllChildren()
	end
	self.MapReady = false
end

function ScopeController:Preload()
	self:ReleaseMap()

	const view = self.View
	const lens = self.Lens
	const map = workspace:FindFirstChild(ScopeSettings.MapName)
	if not view or not lens or not map then
		return
	end

	const wasArchivable = map.Archivable
	map.Archivable = true
	const clone = map:Clone()
	map.Archivable = wasArchivable
	if not clone then
		return
	end

	stripMapClone(clone)
	const lensClone = clone:Clone()
	for index, worldModel in view.WorldModels do
		const copy = if index == 1 then clone else clone:Clone()
		if copy then
			copy.Parent = worldModel
		end
	end
	if lensClone then
		lensClone.Parent = lens.WorldModel
	end

	const lighting = ScopeSettings.Lighting(workspace:GetAttribute(ScopeSettings.MapAttribute) :: string?)
	view.SetLighting(lighting)
	lens.SetLighting(lighting)
	for _, worldModel in view.WorldModels do
		table.insert(self.Characters, ScopeCharacters.new(worldModel))
		table.insert(self.Mirrors, ScopeViewmodel.new(worldModel))
	end
	self.LensCharacters = ScopeCharacters.new(lens.WorldModel)
	self.MapReady = true
end

function ScopeController:SchedulePreload()
	self.PreloadToken += 1
	const token = self.PreloadToken
	task.delay(ScopeSettings.PreloadDelay, function()
		if token == self.PreloadToken then
			self:Preload()
		end
	end)
end

function ScopeController:LensVisibility(alpha: number): number
	if self.Dependencies.ArmsController:IsShootAimPlaying() then
		return 0
	end
	local closeness = 1
	const camera = workspace.CurrentCamera
	const lens = self.Lens
	const apparent = if lens and camera then lens.Apparent() else nil
	if apparent and camera then
		const fraction = apparent.Radius * 2 / camera.ViewportSize.Y
		closeness = math.clamp(
			(ScopeSettings.LensHideFraction - fraction) / (ScopeSettings.LensHideFraction - ScopeSettings.LensShowFraction),
			0,
			1
		)
	end
	return math.clamp((ScopeSettings.LensFadeStart - alpha) / ScopeSettings.LensFadeStart, 0, 1) * closeness
end

function ScopeController:ScopeGeometry(alpha: number): (number, Vector2)
	const camera = workspace.CurrentCamera
	const lens = self.Lens
	const apparent = if lens and camera then lens.Apparent() else nil

	local startFraction = ScopeSettings.FallbackLensFraction
	local startCenter = CENTER
	if apparent and camera then
		const viewportSize = camera.ViewportSize
		startFraction = apparent.Radius * 2 / viewportSize.Y
		startCenter = Vector2.new(apparent.Center.X / viewportSize.X, apparent.Center.Y / viewportSize.Y)
	end

	const fraction = startFraction + (ScopeSettings.CircleFraction - startFraction) * alpha
	return fraction, startCenter:Lerp(CENTER, alpha)
end

function ScopeController:Frame(deltaTime: number)
	const view = self.View
	const lens = self.Lens
	if not view or not lens then
		return
	end

	const aiming = self.Dependencies.ArmsController.IsAiming()
	const target = if self.Model ~= nil and aiming then 1 else 0
	local raw = self.Raw
	const stepSize = deltaTime / ScopeSettings.TransitionSeconds
	raw = if raw < target then math.min(target, raw + stepSize) else math.max(target, raw - stepSize)
	self.Raw = raw
	const alpha = raw * raw * (3 - 2 * raw)

	if self.Kicking then
		self:StepKick(deltaTime)
	end

	const camera = workspace.CurrentCamera
	local kickOffset = Vector2.zero
	if camera and (self.Kicking or self.KickApplied) then
		const viewportSize = camera.ViewportSize
		kickOffset = Vector2.new(self.KickX * viewportSize.Y / viewportSize.X, self.KickY)
	end

	if self.LensAttached then
		if self.Kicking or self.KickApplied then
			const apparent = lens.Apparent()
			const lensFraction = if apparent and camera then apparent.Radius * 2 / camera.ViewportSize.Y else ScopeSettings.FallbackLensFraction
			const lensScale = ScopeSettings.LensKickScale / math.max(lensFraction, 0.05)
			lens.SetKick(Vector2.new(self.KickX, self.KickY) * lensScale, self.KickRoll)
		end
		lens.Render(self:LensVisibility(alpha))
		const lensCharacters = self.LensCharacters
		if lensCharacters and alpha < 1 then
			lensCharacters.Step()
		end
	end

	if alpha > 0 then
		if not self.ViewShown then
			self.ViewShown = true
			view.SetBaseFov(self.Dependencies.OptionsController:Get("Fov"))
			view.Show()
			self.Active(true)
		end

		const fraction, baseCenter = self:ScopeGeometry(alpha)
		const center = baseCenter + kickOffset * alpha
		self.OverlayFraction(fraction)
		self.OverlayCenter(center)
		self.OverlayAlpha(alpha)
		self.OverlayRotation(self.KickRoll * alpha)
		view.Render(alpha, fraction, center)

		for _, characters in self.Characters do
			characters.Step()
		end
	elseif self.ViewShown then
		self.ViewShown = false
		view.Hide()
		self.Active(false)
	end

	self.KickApplied = self.Kicking

	const mirrorOn = alpha > ScopeSettings.MirrorThreshold
	if #self.Mirrors > 0 then
		if mirrorOn ~= self.MirrorOn then
			self.MirrorOn = mirrorOn
			for _, mirror in self.Mirrors do
				mirror.SetVisible(mirrorOn)
			end
			self.Dependencies.ArmsController:SetViewmodelHidden(mirrorOn)
		end
		if mirrorOn then
			for _, mirror in self.Mirrors do
				mirror.Step()
			end
		end
	end
end

function ScopeController:StartRendering(model: Model)
	if self.Rendering then
		return
	end

	const view = self.View
	const lens = self.Lens
	if not view or not lens or not self.MapReady then
		return
	end

	self.Rendering = true
	self.Raw = 0

	const gunData = self.Dependencies.WeaponController:GunData()
	const scope = if gunData then gunData.Scope else nil
	const lensName = if scope then scope.Lens else nil
	const anchor = model:FindFirstChild(ScopeSettings.LensAnchorName, true)
	if scope and anchor and anchor:IsA("Attachment") and anchor.Parent and anchor.Parent:IsA("BasePart") then
		lens.SetFov(scope.Fov)
		self.LensAttached = lens.Attach(anchor.Parent, anchor)
	elseif scope and lensName then
		lens.SetFov(scope.Fov)
		const part = model:FindFirstChild(lensName, true)
		if part and part:IsA("BasePart") then
			self.LensAttached = lens.Attach(part)
		else
			warnLens(lensName)
		end
	end

	const rig = self.Dependencies.ArmsController.Rig
	if rig then
		for _, mirror in self.Mirrors do
			mirror.Build(rig)
		end
	end

	self.OverlayHousing(if scope and scope.HousingColor then scope.HousingColor else ScopeSettings.DefaultHousingColor)

	RunService:BindToRenderStep(ScopeSettings.RenderBindName, Enum.RenderPriority.Camera.Value + 3, function(deltaTime)
		self:Frame(deltaTime)
	end)
end

function ScopeController:StopRendering()
	if not self.Rendering then
		return
	end

	self.Rendering = false
	RunService:UnbindFromRenderStep(ScopeSettings.RenderBindName)
	self:ResetKick()
	self.KickApplied = false
	self.OverlayRotation(0)
	const kickLens = self.Lens
	if kickLens then
		kickLens.SetKick(Vector2.zero, 0)
	end

	self.Raw = 0
	self.LensAttached = false
	self.ViewShown = false
	self.Active(false)

	const lens = self.Lens
	if lens then
		lens.Detach()
	end

	const view = self.View
	if view then
		view.Hide()
	end

	for _, mirror in self.Mirrors do
		mirror.Clear()
	end

	if self.MirrorOn then
		self.MirrorOn = false
		self.Dependencies.ArmsController:SetViewmodelHidden(false)
	end
end

function ScopeController:Sync()
	const model = self:HeldModel()
	if model ~= self.Model then
		self:StopRendering()
		self.Model = model
	end

	if model and self.MapReady and not self.Rendering then
		self:StartRendering(model)
	end
end

function ScopeController:Mount(playerGui: PlayerGui)
	self.View = ScopeView.new(playerGui)
	self.Lens = ScopeLens.new(playerGui)

	self.Unmount = Vide.mount(function()
		return create("ScreenGui")({
			Name = "ScopeUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = ScopeSettings.OverlayDisplayOrder,
			Enabled = self.Active,

			ScopeOverlay.new({
				Fraction = self.OverlayFraction,
				Center = self.OverlayCenter,
				Alpha = self.OverlayAlpha,
				HousingColor = self.OverlayHousing,
				Rotation = self.OverlayRotation,
			}),
		})
	end, playerGui)

	workspace.ChildAdded:Connect(function(child)
		if child.Name == ScopeSettings.MapName then
			self:SchedulePreload()
		end
	end)
	workspace.ChildRemoved:Connect(function(child)
		if child.Name == ScopeSettings.MapName then
			self:SchedulePreload()
		end
	end)
	workspace:GetAttributeChangedSignal(ScopeSettings.MapAttribute):Connect(function()
		self:SchedulePreload()
	end)

	self:SchedulePreload()
end

ScopeController:OnTick(function(self)
	if self.View then
		self:Sync()
	end
end, TICK_RATE)

ScopeController:OnInit(function(self)
	self:Setup()
end)

ScopeController:OnStart(function(self)
	self.Dependencies.HitController.Fired:Connect(function(gunData)
		if gunData.Scope then
			self:Kick()
		end
	end)

	task.spawn(function()
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui)
	end)
end)

return ScopeController
