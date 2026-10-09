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

	task.spawn(function()
		while self.DeathToken == token and self.Dead() do
			self.Remaining(MatchSettings.RespawnDelay - (os.clock() - diedAt))
			task.wait(COUNTDOWN_STEP)
		end
	end)
end

function DeathCameraController:HideDeath()
	self.DeathToken += 1
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

	self.Spectating = true
	self.Dependencies.ArmsController:ClearRig()
	camera.CameraType = Enum.CameraType.Scriptable

	const startCFrame = camera.CFrame
	local elapsed = 0

	RunService:BindToRenderStep(RENDER_BIND_NAME, Enum.RenderPriority.Camera.Value, function(deltaTime: number)
		const root = characterRoot(shooter)
		if not root then
			self:StopSpectating()
			return
		end

		const target = self:GetSpectateCFrame(root)
		if elapsed >= TWEEN_TIME then
			camera.CFrame = target
			return
		end

		elapsed += deltaTime
		camera.CFrame = startCFrame:Lerp(target, math.clamp(elapsed / TWEEN_TIME, 0, 1))
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
		self:ShowDeath()

		if not shooter or shooter == Players.LocalPlayer then
			return
		end

		self:StartSpectating(shooter)
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
