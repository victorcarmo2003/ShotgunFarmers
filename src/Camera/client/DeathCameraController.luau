--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterPlayer = game:GetService("StarterPlayer")
local MatchSettings = require(ReplicatedStorage.shared.Match.MatchSettings)
local ShopCatalog = require(ReplicatedStorage.shared.Shop.ShopCatalog)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local DeathScreen = require(StarterPlayer.StarterPlayerScripts.client.Vital.DeathScreen)

const TWEEN_TIME = 0.6

const THIRD_PERSON_OFFSET = Vector3.new(0, 3, 8)
const LOOK_AT_HEIGHT = 1.5
const SELF_FOCUS_TIME = 1
const SELF_DISTANCE = 9
const SELF_HEIGHT = 4

const RENDER_BIND_NAME = "DeathCameraController_Spectate"
const COUNTDOWN_STEP = 0.1
const DEATH_SCREEN_ORDER = 8

const REVIVE_KEY = Enum.KeyCode.F
const REVIVAL_ITEM = "Revival"
const PRACTICE_MODE = "Practice"

const NO_INFO: DeathScreen.Info = { Killer = "", Gun = "", Headshot = false }

const DeathCameraController = Modux.Controller("DeathCameraController", {
	Require = { "ArmsController", "GameStateController", "MovementController" },
	Priority = 410,
})

function DeathCameraController:Setup()
	self.Spectating = false :: boolean
	self.Dead = Vide.source(false) :: Vide.Source<boolean>
	self.DeathInfo = Vide.source(NO_INFO) :: Vide.Source<DeathScreen.Info>
	self.Remaining = Vide.source(0) :: Vide.Source<number>
	self.DeathToken = 0 :: number
	self.RevivalTokens = Vide.source(0) :: Vide.Source<number>
	self.Killer = nil :: Player?
	self.FocusDone = false :: boolean
end

function DeathCameraController:ReviveText(): string
	if workspace:GetAttribute("GameMode") == PRACTICE_MODE then
		return ""
	end

	const tokens = self.RevivalTokens()
	if tokens > 0 then
		return `[F] REVIVE NOW ({tokens})`
	end

	const item = ShopCatalog.ById(REVIVAL_ITEM)
	return if item then `[F] REVIVE NOW - R$ {item.RobuxPrice}` else ""
end

function DeathCameraController:TryRevive()
	if not self.Dead() then
		return
	end

	if self.RevivalTokens() > 0 then
		self.Libs.Net.Shop.Revive:fireServer()
		return
	end

	const item = ShopCatalog.ById(REVIVAL_ITEM)
	if item then
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, item.ProductId)
	end
end

function DeathCameraController:BindRevive()
	const localPlayer = Players.LocalPlayer
	const sync = function()
		const value = localPlayer:GetAttribute(ShopCatalog.REVIVAL_ATTRIBUTE)
		self.RevivalTokens(if typeof(value) == "number" then value else 0)
	end
	sync()
	localPlayer:GetAttributeChangedSignal(ShopCatalog.REVIVAL_ATTRIBUTE):Connect(sync)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == REVIVE_KEY then
			self:TryRevive()
		end
	end)
end

function DeathCameraController:ShowDeath()
	if self.Dead() then
		return
	end

	self.DeathToken += 1
	const token = self.DeathToken
	const diedAt = os.clock()
	self.Remaining(MatchSettings.RespawnDelay)
	self.Dead(true)
	self.FocusDone = false
	self:FocusSelf()

	task.delay(SELF_FOCUS_TIME, function()
		if self.DeathToken ~= token or not self.Dead() then
			return
		end
		self.FocusDone = true
		const killer = self.Killer
		if killer then
			self:StartSpectating(killer)
		end
	end)

	task.spawn(function()
		while self.DeathToken == token and self.Dead() do
			self.Remaining(MatchSettings.RespawnDelay - (os.clock() - diedAt))
			task.wait(COUNTDOWN_STEP)
		end
	end)
end

function DeathCameraController:HideDeath()
	self.DeathToken += 1
	self.Killer = nil
	self.FocusDone = false
	Vide.batch(function()
		self.Dead(false)
		self.DeathInfo(NO_INFO)
	end)
end

function DeathCameraController:BindHumanoid(character: Model)
	const humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			self:ShowDeath()
		end)
	end
end

function DeathCameraController:MountDeathScreen()
	const gameState = self.Dependencies.GameStateController
	Vide.mount(function()
		return Vide.create("ScreenGui")({
			Name = "DeathScreenUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = DEATH_SCREEN_ORDER,
			Enabled = function()
				return gameState:IsInMatch()
			end,

			DeathScreen({
				Visible = self.Dead,
				Info = self.DeathInfo,
				Remaining = self.Remaining,
				ReviveText = function()
					return self:ReviveText()
				end,
				OnRevive = function()
					self:TryRevive()
				end,
			}),
		})
	end, Players.LocalPlayer:WaitForChild("PlayerGui"))
end

local function playerFromGameID(id: number): Player?
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("GameID") == id then
			return player
		end
	end

	return nil
end

local function characterRoot(player: Player): BasePart?
	const character = player.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

function DeathCameraController:GetSpectateCFrame(shooterRoot: BasePart): CFrame
	const lookAt = shooterRoot.Position + Vector3.new(0, LOOK_AT_HEIGHT, 0)
	const position = shooterRoot.CFrame:PointToWorldSpace(THIRD_PERSON_OFFSET)
	return CFrame.lookAt(position, lookAt)
end

local function showCharacter(character: Model?)
	if not character then
		return
	end
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = 0
		end
	end
end

function DeathCameraController:Bind(step: (camera: Camera, deltaTime: number) -> ())
	const camera = workspace.CurrentCamera
	if not camera then
		return
	end

	if self.Spectating then
		RunService:UnbindFromRenderStep(RENDER_BIND_NAME)
	end
	self.Spectating = true
	self.Dependencies.ArmsController:ClearRig()
	camera.CameraType = Enum.CameraType.Scriptable

	RunService:BindToRenderStep(RENDER_BIND_NAME, Enum.RenderPriority.Camera.Value, function(deltaTime: number)
		showCharacter(Players.LocalPlayer.Character)
		step(camera, deltaTime)
	end)
end

function DeathCameraController:FocusSelf()
	const camera = workspace.CurrentCamera
	if not camera or not characterRoot(Players.LocalPlayer) then
		self.Dependencies.ArmsController:ClearRig()
		return
	end

	const startCFrame = camera.CFrame
	local back = -startCFrame.LookVector * Vector3.new(1, 0, 1)
	back = if back.Magnitude > 0.01 then back.Unit else Vector3.zAxis
	const offset = back * SELF_DISTANCE + Vector3.yAxis * SELF_HEIGHT
	local elapsed = 0

	self:Bind(function(currentCamera: Camera, deltaTime: number)
		const root = characterRoot(Players.LocalPlayer)
		if not root then
			return
		end

		const lookAt = root.Position + Vector3.new(0, LOOK_AT_HEIGHT, 0)
		const target = CFrame.lookAt(lookAt + offset, lookAt)
		elapsed += deltaTime
		const alpha = math.clamp(elapsed / TWEEN_TIME, 0, 1)
		currentCamera.CFrame = if alpha >= 1 then target else startCFrame:Lerp(target, alpha)
		currentCamera.Focus = CFrame.new(lookAt)
	end)
end

function DeathCameraController:StopSpectating()
	if not self.Spectating then
		return
	end
	self.Spectating = false

	RunService:UnbindFromRenderStep(RENDER_BIND_NAME)

	const camera = workspace.CurrentCamera
	if not camera then
		return
	end

	camera.CameraType = Enum.CameraType.Custom

	const humanoid = self.Dependencies.MovementController.Humanoid
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

function DeathCameraController:StartSpectating(shooter: Player)
	const camera = workspace.CurrentCamera
	if not camera or not characterRoot(shooter) then
		return
	end

	const startCFrame = camera.CFrame
	local elapsed = 0

	self:Bind(function(currentCamera: Camera, deltaTime: number)
		const root = characterRoot(shooter)
		if not root then
			return
		end

		const target = self:GetSpectateCFrame(root)
		elapsed += deltaTime
		const alpha = math.clamp(elapsed / TWEEN_TIME, 0, 1)
		currentCamera.CFrame = if alpha >= 1 then target else startCFrame:Lerp(target, alpha)
		currentCamera.Focus = CFrame.new(root.Position)
	end)
end

DeathCameraController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.KillFeed.Kill:onClient(function(data)
		const localGameID = Players.LocalPlayer:GetAttribute("GameID")
		if localGameID == nil or data.VictimID ~= localGameID then
			return
		end

		const shooter = playerFromGameID(data.ShooterID)
		self.DeathInfo({
			Killer = if shooter and shooter ~= Players.LocalPlayer then shooter.DisplayName else "",
			Gun = data.GunName,
			Headshot = data.IsHeadshot,
		})
		self.Killer = if shooter and shooter ~= Players.LocalPlayer then shooter else nil
		self:ShowDeath()

		const killer = self.Killer
		if killer and self.FocusDone then
			self:StartSpectating(killer)
		end
	end)
end)

DeathCameraController:OnStart(function(self)
	const localPlayer = Players.LocalPlayer
	localPlayer.CharacterAdded:Connect(function(character: Model)
		self:StopSpectating()
		self:HideDeath()
		self:BindHumanoid(character)
	end)

	if localPlayer.Character then
		task.spawn(function()
			self:BindHumanoid(localPlayer.Character :: Model)
		end)
	end

	self:BindRevive()
	self:MountDeathScreen()
end)

return DeathCameraController
