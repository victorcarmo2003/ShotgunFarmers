--!strict
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local ErrorPopup = require(StarterPlayer.StarterPlayerScripts.client.Match.ErrorPopup)
local LobbyScreen = require(StarterPlayer.StarterPlayerScripts.client.Lobby.LobbyScreen)
local ShopScreen = require(StarterPlayer.StarterPlayerScripts.client.Shop.ShopScreen)
local CosmeticsScreen = require(StarterPlayer.StarterPlayerScripts.client.Cosmetics.CosmeticsScreen)
local GameSelectionScreen = require(StarterPlayer.StarterPlayerScripts.client.GameSelection.GameSelectionScreen)
local CareerScreen = require(StarterPlayer.StarterPlayerScripts.client.Career.CareerScreen)
local QuestsScreen = require(StarterPlayer.StarterPlayerScripts.client.Quests.QuestsScreen)
local FriendsScreen = require(StarterPlayer.StarterPlayerScripts.client.Party.FriendsScreen)
local SocialService = game:GetService("SocialService")

const create = Vide.create
const source = Vide.source

const LOBBY_WAIT = 30
const CAMERA_PART_WAIT = 10
const CONTROLS_WAIT = 10

const DEFAULT_CAMERA = "CameraPosition1"

type ScreenProps = {
	Visible: (() -> boolean)?,
	OnClose: (() -> ())?,
	OnSelectMode: ((mode: GameSelectionScreen.Mode) -> ())?,
	OnJoinRoom: (() -> ())?,
	OnCreateRoom: (() -> ())?,
	OnBuyRobux: ((id: string) -> ())?,
	OnBuyCoins: ((id: string) -> ())?,
	PlayerName: (() -> string)?,
	Level: (() -> number)?,
	Xp: (() -> number)?,
	XpMax: (() -> number)?,
	Stats: (() -> { CareerScreen.Stat })?,
	OnRedeem: ((id: string) -> ())?,
	Status: (() -> string)?,
	Friends: (() -> { FriendsScreen.Friend })?,
	Sent: (() -> { [number]: boolean })?,
	Loading: (() -> boolean)?,
	OnInviteFriend: ((userId: number) -> ())?,
}

type ScreenComponent = (props: ScreenProps) -> Frame

const SCREENS: { [string]: { Component: ScreenComponent, Camera: string? } } = {
	Shop = {
		Component = function(props: ScreenProps): Frame
			return ShopScreen({
				Visible = props.Visible,
				OnClose = props.OnClose,
				OnBuyRobux = props.OnBuyRobux,
				OnBuyCoins = props.OnBuyCoins,
			})
		end,
	},
	Customize = {
		Component = function(props: ScreenProps): Frame
			return CosmeticsScreen({
				Visible = props.Visible,
				OnClose = props.OnClose,
			})
		end,
		Camera = "CameraPosition2",
	},
	Play = {
		Component = function(props: ScreenProps): Frame
			return GameSelectionScreen({
				Visible = props.Visible,
				OnClose = props.OnClose,
				OnSelectMode = props.OnSelectMode,
				OnJoinRoom = props.OnJoinRoom,
				OnCreateRoom = props.OnCreateRoom,
				Status = props.Status,
			})
		end,
	},
	Carrer = {
		Component = function(props: ScreenProps): Frame
			return CareerScreen({
				Visible = props.Visible,
				OnClose = props.OnClose,
				PlayerName = props.PlayerName,
				Level = props.Level,
				Xp = props.Xp,
				XpMax = props.XpMax,
				Stats = props.Stats,
			})
		end,
	},
	Friends = {
		Component = function(props: ScreenProps): Frame
			return FriendsScreen({
				Visible = props.Visible,
				OnClose = props.OnClose,
				Friends = props.Friends,
				Sent = props.Sent,
				Loading = props.Loading,
				OnInvite = props.OnInviteFriend,
			})
		end,
	},
	Quests = {
		Component = function(props: ScreenProps): Frame
			return QuestsScreen({
				Visible = props.Visible,
				OnClose = props.OnClose,
				OnRedeem = props.OnRedeem,
			})
		end,
	},
}

const LobbyController = Modux.Controller("LobbyController", {
	Require = {
		"GameStateController",
		"CareerController",
		"ProfileController",
		"OnlineController",
		"MatchmakingController",
		"PartyController",
	},
	Priority = 450,
})

function LobbyController:Setup()
	self.Active = false :: boolean
	self.CameraPart = nil :: BasePart?
	self.CameraConnections = {} :: { RBXScriptConnection }
	self.PopupUnmount = nil :: (() -> ())?
	self.CameraChangedConnection = nil :: RBXScriptConnection?
	self.ErrorShown = false :: boolean
	self.Inviting = false :: boolean
	self.Token = 0 :: number
	self.ScreenUnmount = nil :: (() -> ())?
	self.CurrentScreen = source("") :: Vide.Source<string>
end

function LobbyController:Open(name: string)
	if SCREENS[name] == nil then
		warn(`[LobbyController] tela desconhecida: {name}`)
		return
	end

	self.CurrentScreen(name)
	self:UpdateCamera()
end

function LobbyController:Close()
	const matchmaking = self.Dependencies.MatchmakingController
	if self.CurrentScreen() == "Play" and matchmaking.State() == "Searching" then
		matchmaking:Cancel()
	end

	self.CurrentScreen("")
	self:UpdateCamera()
end

function LobbyController:Toggle(name: string)
	if self.CurrentScreen() == name then
		self:Close()
	else
		self:Open(name)
	end
end

function LobbyController:UpdateCamera()
	if not self.Active then
		return
	end

	const lobby = workspace:FindFirstChild("Lobby")
	if not lobby then
		return
	end

	const current = self.CurrentScreen()
	const entry = SCREENS[current]
	const cameraName = if entry and entry.Camera then entry.Camera else DEFAULT_CAMERA
	const part = lobby:FindFirstChild(cameraName, true)
	if part and part:IsA("BasePart") then
		self.CameraPart = part
		self:ApplyCamera()
	end
end

function LobbyController:SelectMode(mode: GameSelectionScreen.Mode)
	const matchmaking = self.Dependencies.MatchmakingController
	if matchmaking:IsBusy() then
		return
	end

	task.spawn(function()
		const accepted, reason = matchmaking:Play(mode)
		if not accepted then
			self:ShowError(reason)
		end
	end)
end

function LobbyController:StatusText(): string
	const state = self.Dependencies.MatchmakingController.State()
	if state == "Searching" then
		return "SEARCHING..."
	elseif state == "Teleporting" then
		return "JOINING..."
	end
	return ""
end

function LobbyController:JoinRoom()
	print("[LobbyController] join room")
end

function LobbyController:CreateRoom()
	print("[LobbyController] create room")
end

function LobbyController:BuyRobux(id: string)
	print(`[LobbyController] comprar com robux: {id}`)
end

function LobbyController:BuyCoins(id: string)
	print(`[LobbyController] comprar com moedas: {id}`)
end

function LobbyController:RedeemQuest(id: string)
	print(`[LobbyController] resgatar quest: {id}`)
end

function LobbyController:Invite()
	if self.Inviting then
		return
	end

	self.Inviting = true
	const friends = self.Dependencies.PartyController:LoadFriends()
	self.Inviting = false

	if #friends > 0 then
		self:Open("Friends")
		return
	end

	self:PromptRobloxInvite()
end

function LobbyController:InviteFriend(userId: number)
	task.spawn(function()
		const sent, reason = self.Dependencies.PartyController:Invite(userId)
		if not sent then
			self:ShowError(reason, "SQUAD")
		end
	end)
end

function LobbyController:PromptRobloxInvite()
	const player = Players.LocalPlayer
	const allowed, canInvite = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if not allowed or not canInvite then
		return
	end

	const options = Instance.new("ExperienceInviteOptions")
	const lobbyId = workspace:GetAttribute("LobbyId")
	if typeof(lobbyId) == "string" and lobbyId ~= "" then
		options.LaunchData = HttpService:JSONEncode({ Lobby = lobbyId })
	end

	pcall(function()
		SocialService:PromptGameInvite(player, options)
	end)
end

function LobbyController:MountScreen()
	if self.ScreenUnmount then
		return
	end

	const gameState = self.Dependencies.GameStateController
	const career = self.Dependencies.CareerController
	const online = self.Dependencies.OnlineController
	const playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	const unmountScreens = Vide.mount(function()
		const screens: { Instance } = {}
		for name, entry in SCREENS do
			table.insert(
				screens,
				entry.Component({
					Visible = function()
						return self.CurrentScreen() == name
					end,
					OnClose = function()
						self:Close()
					end,
					OnSelectMode = function(mode)
						self:SelectMode(mode)
					end,
					OnJoinRoom = function()
						self:JoinRoom()
					end,
					OnCreateRoom = function()
						self:CreateRoom()
					end,
					OnBuyRobux = function(id)
						self:BuyRobux(id)
					end,
					OnBuyCoins = function(id)
						self:BuyCoins(id)
					end,
					OnRedeem = function(id)
						self:RedeemQuest(id)
					end,
					Status = function()
						return self:StatusText()
					end,
					Friends = function()
						return self.Dependencies.PartyController.Friends()
					end,
					Sent = function()
						return self.Dependencies.PartyController.Sent()
					end,
					Loading = function()
						return self.Dependencies.PartyController.Loading()
					end,
					OnInviteFriend = function(userId)
						self:InviteFriend(userId)
					end,
					PlayerName = function()
						return Players.LocalPlayer.DisplayName
					end,
					Level = career.Level,
					Xp = career.Xp,
					XpMax = career.XpMax,
					Stats = career.Stats,
				})
			)
		end

		return create("ScreenGui")({
			Name = "LobbyScreensUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 0,
			Enabled = function()
				return gameState.State() == "Lobby"
			end,

			screens,
		})
	end, playerGui)

	const unmountLobby = Vide.mount(function()
		return create("ScreenGui")({
			Name = "LobbyUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 1,
			Enabled = function()
				return gameState.State() == "Lobby"
			end,

			LobbyScreen({
				Visible = function()
					return true
				end,
				PlayersOnline = function()
					return online.Online()
				end,
				Balance = function()
					return self.Dependencies.ProfileController.Gems()
				end,
				Selected = function()
					return self.CurrentScreen()
				end,
				OnNavigate = function(name)
					self:Toggle(name)
				end,
				OnInvite = function()
					task.spawn(function()
						self:Invite()
					end)
				end,
			}),
		})
	end, playerGui)

	self.ScreenUnmount = function()
		unmountScreens()
		unmountLobby()
	end
end

function LobbyController:DisableControls()
	const scripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
	const module = scripts:WaitForChild("PlayerModule", CONTROLS_WAIT)
	if not module or not module:IsA("ModuleScript") then
		warn("[LobbyController] PlayerModule nao encontrado")
		return
	end

	const disabled, reason = pcall(function()
		(require(module) :: any):GetControls():Disable()
	end)
	if not disabled then
		warn(`[LobbyController] falha ao desabilitar controles: {tostring(reason)}`)
	end
end

function LobbyController:ApplyCamera()
	const camera = workspace.CurrentCamera
	const part = self.CameraPart
	if not camera or not part then
		return
	end

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = part.CFrame
end

function LobbyController:ClearCameraConnections()
	for _, connection in self.CameraConnections do
		connection:Disconnect()
	end
	table.clear(self.CameraConnections)
end

function LobbyController:BindCamera()
	self:ClearCameraConnections()

	const camera = workspace.CurrentCamera
	if not camera then
		return
	end

	self:ApplyCamera()

	table.insert(
		self.CameraConnections,
		camera:GetPropertyChangedSignal("CameraType"):Connect(function()
			if self.Active and camera.CameraType ~= Enum.CameraType.Scriptable then
				self:ApplyCamera()
			end
		end)
	)
end

function LobbyController:FindCameraPart(): BasePart?
	const lobby = workspace:WaitForChild("Lobby", LOBBY_WAIT)
	if not lobby then
		return nil
	end

	const part = lobby:FindFirstChild("CameraPosition1", true) or lobby:WaitForChild("CameraPosition1", CAMERA_PART_WAIT)
	return if part and part:IsA("BasePart") then part else nil
end

function LobbyController:EnableControls()
	const scripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
	const module = if scripts then scripts:FindFirstChild("PlayerModule") else nil
	if not module or not module:IsA("ModuleScript") then
		return
	end

	const enabled, reason = pcall(function()
		(require(module) :: any):GetControls():Enable()
	end)
	if not enabled then
		warn(`[LobbyController] falha ao habilitar controles: {tostring(reason)}`)
	end
end

function LobbyController:EnterLobby()
	self.Active = true
	self.Token += 1
	const token = self.Token

	self:DisableControls()

	const part = self:FindCameraPart()
	if not part then
		warn("[LobbyController] CameraPosition1 nao encontrada")
		return
	end

	if not self.Active or token ~= self.Token then
		return
	end

	self.CameraPart = part
	self:BindCamera()

	if self.CameraChangedConnection then
		self.CameraChangedConnection:Disconnect()
	end

	self.CameraChangedConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if self.Active then
			self:BindCamera()
		end
	end)
end

function LobbyController:ExitLobby()
	self.Active = false
	self.Token += 1
	self.CameraPart = nil
	self.CurrentScreen("")

	self:ClearCameraConnections()

	if self.CameraChangedConnection then
		self.CameraChangedConnection:Disconnect()
		self.CameraChangedConnection = nil
	end

	self:EnableControls()

	const camera = workspace.CurrentCamera
	if not camera then
		return
	end

	camera.CameraType = Enum.CameraType.Custom

	const character = Players.LocalPlayer.Character
	const humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

function LobbyController:OnState(state: string)
	if state ~= "Loading" and not self.ErrorShown then
		self.ErrorShown = true

		const errorMessage = workspace:GetAttribute("ServerRoleError")
		if typeof(errorMessage) == "string" then
			self:ShowError(errorMessage)
		end
	end

	if state == "Lobby" then
		if not self.Active then
			task.spawn(function()
				self:EnterLobby()
			end)
		end
	elseif self.Active then
		self:ExitLobby()
	end
end

function LobbyController:ShowError(message: string, title: string?)
	if self.PopupUnmount then
		self.PopupUnmount()
		self.PopupUnmount = nil
	end

	self.PopupUnmount = Vide.mount(function()
		return create("ScreenGui")({
			Name = "MatchErrorUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 100,

			ErrorPopup({
				Title = title or "Erro",
				Message = message,
				OnClose = function()
					const unmount = self.PopupUnmount
					self.PopupUnmount = nil
					if unmount then
						unmount()
					end
				end,
			}),
		})
	end, Players.LocalPlayer:WaitForChild("PlayerGui"))
end

LobbyController:OnInit(function(self)
	self:Setup()
end)

LobbyController:OnStart(function(self)
	self.Dependencies.MatchmakingController.Failed:Connect(function(reason)
		self:ShowError(reason)
	end)

	self.Dependencies.PartyController.Notice:Connect(function(message)
		self:ShowError(message, "SQUAD")
	end)

	self.Dependencies.PartyController.InviteRequested:Connect(function()
		task.spawn(function()
			self:Invite()
		end)
	end)

	const gameState = self.Dependencies.GameStateController
	gameState.Changed:Connect(function(state)
		self:OnState(state)
	end)

	self:OnState(gameState:Get())

	task.spawn(function()
		self:MountScreen()
	end)
end)

return LobbyController
