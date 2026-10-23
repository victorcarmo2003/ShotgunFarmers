--!strict
local ContentProvider = game:GetService("ContentProvider")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local ErrorPopup = require(StarterPlayer.StarterPlayerScripts.client.Match.ErrorPopup)
local LobbyScreen = require(StarterPlayer.StarterPlayerScripts.client.Lobby.LobbyScreen)
local ShopScreen = require(StarterPlayer.StarterPlayerScripts.client.Shop.ShopScreen)
local CosmeticsScreen = require(StarterPlayer.StarterPlayerScripts.client.Cosmetics.CosmeticsScreen)
local WeaponInspector = require(StarterPlayer.StarterPlayerScripts.client.Cosmetics.WeaponInspector)
local GameSelectionScreen = require(StarterPlayer.StarterPlayerScripts.client.GameSelection.GameSelectionScreen)
local CreateRoomScreen = require(StarterPlayer.StarterPlayerScripts.client.GameSelection.CreateRoomScreen)
local JoinRoomScreen = require(StarterPlayer.StarterPlayerScripts.client.GameSelection.JoinRoomScreen)
local CareerScreen = require(StarterPlayer.StarterPlayerScripts.client.Career.CareerScreen)
local QuestsScreen = require(StarterPlayer.StarterPlayerScripts.client.Quests.QuestsScreen)
local FriendsScreen = require(StarterPlayer.StarterPlayerScripts.client.Party.FriendsScreen)
local SocialService = game:GetService("SocialService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local ShopCatalog = require(ReplicatedStorage.shared.Shop.ShopCatalog)
local MatchSettings = require(ReplicatedStorage.shared.Match.MatchSettings)
local SkinCatalog = require(ReplicatedStorage.shared.Shop.SkinCatalog)
local UISounds = require(StarterPlayer.StarterPlayerScripts.client.Interface.UISounds)

const create = Vide.create
const source = Vide.source

const LOBBY_WAIT = 30
const CAMERA_PART_WAIT = 10
const CONTROLS_WAIT = 10

const DEFAULT_CAMERA = "CameraPosition1"
const RETURN_KEY = Enum.KeyCode.Q

const CAMERA_SMOOTH = 5
const MOUSE_SMOOTH = 4
const MOUSE_MOVE = 0.35
const MOUSE_YAW = 0.035
const MOUSE_PITCH = 0.025

const HIDE_OTHERS_SCREENS: { [string]: boolean } = { Customize = true }
const CUSTOMIZE_POSITION = "6"
const PRELOAD_FOLDERS = { "SkinTextures", "SkinMeshes" }
const LOADING_DONE_ATTRIBUTE = "LoadingDone"
const PRELOAD_WAIT = 20
const PRELOAD_POLL = 0.25
const POPUP_BACKDROP_TRANSPARENCY = 0.45

const ROOM_SCREENS: { [string]: boolean } = { CreateRoom = true, JoinRoom = true }
const SEARCH_SCREENS: { [string]: boolean } = { Play = true, CreateRoom = true, JoinRoom = true }

type ScreenProps = {
	Visible: (() -> boolean)?,
	OnClose: (() -> ())?,
	OnSelectMode: ((mode: GameSelectionScreen.Mode) -> ())?,
	OnJoinRoom: (() -> ())?,
	OnCreateRoom: (() -> ())?,
	OnCreate: ((mode: CreateRoomScreen.RoomMode, mapName: string, private: boolean) -> ())?,
	Rooms: (() -> { JoinRoomScreen.Room })?,
	RoomsLoading: (() -> boolean)?,
	OnRefreshRooms: (() -> ())?,
	OnJoinCode: ((code: string) -> ())?,
	OnJoinMatch: ((key: string) -> ())?,
	OnBuyRobux: ((id: string) -> ())?,
	OnBuyCoins: ((id: string) -> ())?,
	OnEquipSkin: ((id: string) -> ())?,
	OnEquipDefault: ((gun: string) -> ())?,
	OnUseSkin: ((id: string) -> ())?,
	OnSelectGun: ((gun: string) -> ())?,
	OnPreviewSkin: ((gun: string, id: string?) -> ())?,
	OnRedeemCode: ((code: string) -> ())?,
	OwnedSkins: (() -> { [string]: boolean })?,
	EquippedSkins: (() -> { [string]: string })?,
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
	Squad: (() -> { FriendsScreen.SquadMember })?,
	CanKick: (() -> boolean)?,
	CanLeave: (() -> boolean)?,
	OnKick: ((userId: number) -> ())?,
	OnLeave: (() -> ())?,
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
				OnEquip = props.OnEquipSkin,
				Owned = props.OwnedSkins,
				Equipped = props.EquippedSkins,
				OnRedeemCode = props.OnRedeemCode,
			})
		end,
	},
	Customize = {
		Component = function(props: ScreenProps): Frame
			return CosmeticsScreen({
				Visible = props.Visible,
				OnClose = props.OnClose,
				Owned = props.OwnedSkins,
				Equipped = props.EquippedSkins,
				OnEquip = props.OnUseSkin,
				OnEquipDefault = props.OnEquipDefault,
				OnSelectGun = props.OnSelectGun,
				OnPreview = props.OnPreviewSkin,
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
	CreateRoom = {
		Component = function(props: ScreenProps): Frame
			return CreateRoomScreen({
				Visible = props.Visible,
				OnClose = props.OnClose,
				OnCreate = props.OnCreate,
				Status = props.Status,
			})
		end,
	},
	JoinRoom = {
		Component = function(props: ScreenProps): Frame
			return JoinRoomScreen({
				Visible = props.Visible,
				OnClose = props.OnClose,
				Rooms = props.Rooms,
				Loading = props.RoomsLoading,
				OnRefresh = props.OnRefreshRooms,
				OnJoinCode = props.OnJoinCode,
				OnJoinRoom = props.OnJoinMatch,
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
				Squad = props.Squad,
				CanKick = props.CanKick,
				CanLeave = props.CanLeave,
				OnKick = props.OnKick,
				OnLeave = props.OnLeave,
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
		"FunnelController",
		"ProfileController",
		"OnlineController",
		"MatchmakingController",
		"PartyController",
		"ShopController",
	},
	Priority = 450,
})

function LobbyController:Setup()
	self.Active = false :: boolean
	self.CameraPart = nil :: BasePart?
	self.CameraCFrame = nil :: CFrame?
	self.MouseOffset = Vector2.zero :: Vector2
	self.OthersHidden = false :: boolean
	self.Staged = false :: boolean
	self.StagedFrom = nil :: CFrame?
	self.Inspector = WeaponInspector.new() :: WeaponInspector.Inspector
	self.Inspecting = false :: boolean
	self.CustomizeGun = nil :: string?
	self.CosmeticsPreloaded = false :: boolean
	self.HideConnections = {} :: { RBXScriptConnection }
	self.CameraConnections = {} :: { RBXScriptConnection }
	self.PopupUnmount = nil :: (() -> ())?
	self.PopupInput = nil :: RBXScriptConnection?
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

	if self.CurrentScreen() ~= name then
		UISounds.Play("Open")
		if name == "Shop" then
			self.Dependencies.FunnelController:Track("RobuxShop", "OpenedShop")
		elseif name == "Customize" then
			self.Dependencies.FunnelController:Track("Skins", "OpenedCosmetics")
		elseif name == "Friends" then
			self.Dependencies.FunnelController:Track("Party", "OpenedFriends")
		end
	end
	self.CurrentScreen(name)
	self:UpdateCamera()
end

function LobbyController:Close()
	const matchmaking = self.Dependencies.MatchmakingController
	const current = self.CurrentScreen()
	if SEARCH_SCREENS[current] and matchmaking.State() == "Searching" then
		matchmaking:Cancel()
	end

	self.CurrentScreen(if ROOM_SCREENS[current] then "Play" else "")
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

	self:SyncOthers()
	self:SyncStage()
end

function LobbyController:HideCharacter(character: Model?)
	if not character then
		return
	end

	const hidden = self.OthersHidden
	const value = if hidden then 1 else 0
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = value
		elseif descendant:IsA("Decal") then
			(descendant :: any).LocalTransparencyModifier = value
		elseif descendant:IsA("BillboardGui") then
			descendant.Enabled = not hidden
		end
	end
end

function LobbyController:WatchCharacter(character: Model)
	self:HideCharacter(character)
	table.insert(
		self.HideConnections,
		character.DescendantAdded:Connect(function()
			if self.OthersHidden then
				self:HideCharacter(character)
			end
		end)
	)
end

function LobbyController:TrackOther(player: Player)
	table.insert(
		self.HideConnections,
		player.CharacterAdded:Connect(function(character)
			self:WatchCharacter(character)
		end)
	)
	if player.Character then
		self:WatchCharacter(player.Character)
	end
end

function LobbyController:Inspect(gun: string, skinId: string?)
	if not self.Active or self.CurrentScreen() ~= "Customize" then
		return
	end

	const skin = if skinId then SkinCatalog.ById(skinId) else nil
	self.Inspector.Show(gun, skin)
	self.Inspecting = true
	self.Dependencies.FunnelController:Track("Skins", "InspectedWeapon", gun)
end

function LobbyController:InspectEquipped(gun: string)
	self:Inspect(gun, self.Dependencies.ProfileController.EquippedSkins()[gun])
end

function LobbyController:SetSkin(id: string)
	if not SkinCatalog.ById(id) then
		return
	end

	task.spawn(function()
		const accepted, reason = self.Dependencies.ShopController:EquipSkin(id, true)
		if not accepted then
			self:ShowError(reason, "SHOP")
		end
	end)
end

function LobbyController:CustomizePart(): BasePart?
	const lobby = workspace:FindFirstChild("Lobby")
	const positions = if lobby then lobby:FindFirstChild("CharacterPositions") else nil
	const part = if positions then positions:FindFirstChild(CUSTOMIZE_POSITION) else nil
	return if part and part:IsA("BasePart") then part else nil
end

function LobbyController:SyncStage()
	const active = self.Active and HIDE_OTHERS_SCREENS[self.CurrentScreen()] == true
	self.Dependencies.PartyController.BillboardsHidden(active)

	if active then
		const gun = self.CustomizeGun
		if gun and not self.Inspecting then
			self:InspectEquipped(gun)
		end
	elseif self.Inspecting then
		self.Inspecting = false
		self.Inspector.Hide()
	end

	if active == self.Staged then
		return
	end

	const character = Players.LocalPlayer.Character
	if active then
		const part = self:CustomizePart()
		if not character or not part then
			warn(`[LobbyController] Lobby.CharacterPositions.{CUSTOMIZE_POSITION} nao encontrada`)
			return
		end
		self.Staged = true
		self.StagedFrom = character:GetPivot()
		character:PivotTo(part.CFrame + MatchSettings.SpawnOffset)
		return
	end

	self.Staged = false
	const from = self.StagedFrom
	self.StagedFrom = nil
	if character and from then
		character:PivotTo(from)
	end
end

function LobbyController:SyncOthers()
	const hidden = self.Active and HIDE_OTHERS_SCREENS[self.CurrentScreen()] == true
	if hidden == self.OthersHidden then
		return
	end

	self.OthersHidden = hidden
	for _, connection in self.HideConnections do
		connection:Disconnect()
	end
	table.clear(self.HideConnections)

	if hidden then
		table.insert(
			self.HideConnections,
			Players.PlayerAdded:Connect(function(player)
				self:TrackOther(player)
			end)
		)
		for _, player in Players:GetPlayers() do
			self:TrackOther(player)
		end
	else
		for _, player in Players:GetPlayers() do
			self:HideCharacter(player.Character)
		end
	end
end

function LobbyController:Request(call: () -> (boolean, string))
	if self.Dependencies.MatchmakingController:IsBusy() then
		return
	end

	task.spawn(function()
		const accepted, reason = call()
		if not accepted then
			self:ShowError(reason)
		end
	end)
end

function LobbyController:SelectMode(mode: GameSelectionScreen.Mode)
	self:Request(function()
		return self.Dependencies.MatchmakingController:Play(mode)
	end)
end

function LobbyController:SubmitRoom(mode: CreateRoomScreen.RoomMode, mapName: string, private: boolean)
	self:Request(function()
		return self.Dependencies.MatchmakingController:CreateRoom(mode, mapName, private)
	end)
end

function LobbyController:JoinCode(code: string)
	self:Request(function()
		return self.Dependencies.MatchmakingController:JoinRoom(code)
	end)
end

function LobbyController:JoinMatch(key: string)
	self:Request(function()
		return self.Dependencies.MatchmakingController:JoinMatch(key)
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
	self:Open("JoinRoom")
	self.Dependencies.MatchmakingController:RefreshRooms()
end

function LobbyController:CreateRoom()
	self:Open("CreateRoom")
end

function LobbyController:BuyRobux(id: string)
	const skin = SkinCatalog.ById(id)
	if skin then
		if skin.GamepassId <= 0 then
			self:ShowError("Coming soon", "SHOP")
			return
		end
		self.Dependencies.FunnelController:Track("Skins", "TriedBuy", skin.Id)
		MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, skin.GamepassId)
		return
	end

	const item = ShopCatalog.ById(id)
	if not item then
		return
	end

	const funnel = self.Dependencies.FunnelController
	funnel:Track("RobuxShop", "ClickedItem", item.Id)
	MarketplaceService:PromptProductPurchase(Players.LocalPlayer, item.ProductId)
	funnel:Track("RobuxShop", "PromptOpened", item.Id)
end

function LobbyController:BuyCoins(id: string)
	if not SkinCatalog.ById(id) then
		return
	end

	task.spawn(function()
		const accepted, reason = self.Dependencies.ShopController:BuySkin(id)
		if not accepted then
			self:ShowError(reason, "SHOP")
		end
	end)
end

function LobbyController:ToggleSkin(id: string)
	const skin = SkinCatalog.ById(id)
	if not skin then
		return
	end

	const equip = self.Dependencies.ProfileController.EquippedSkins()[skin.Gun] ~= id
	task.spawn(function()
		const accepted, reason = self.Dependencies.ShopController:EquipSkin(id, equip)
		if not accepted then
			self:ShowError(reason, "SHOP")
		end
	end)
end

function LobbyController:RedeemCode(code: string)
	task.spawn(function()
		const accepted, message = self.Dependencies.ShopController:RedeemCode(code)
		if accepted then
			self:ShowError(message, "CODE REDEEMED", true)
		else
			self:ShowError(message, "INVALID CODE")
		end
	end)
end

function LobbyController:UnequipGun(gun: string)
	const id = self.Dependencies.ProfileController.EquippedSkins()[gun]
	if not id then
		return
	end

	task.spawn(function()
		const accepted, reason = self.Dependencies.ShopController:EquipSkin(id, false)
		if not accepted then
			self:ShowError(reason, "SHOP")
		end
	end)
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

function LobbyController:SquadOthers(): { FriendsScreen.SquadMember }
	const others: { FriendsScreen.SquadMember } = {}
	const localId = Players.LocalPlayer.UserId
	for _, member in self.Dependencies.PartyController.Members() do
		if member.UserId ~= localId then
			table.insert(others, { UserId = member.UserId, Name = member.Name })
		end
	end
	return others
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
					OnCreate = function(mode, mapName, private)
						self:SubmitRoom(mode, mapName, private)
					end,
					Rooms = self.Dependencies.MatchmakingController.Rooms,
					RoomsLoading = self.Dependencies.MatchmakingController.RoomsLoading,
					OnRefreshRooms = function()
						self.Dependencies.MatchmakingController:RefreshRooms()
					end,
					OnJoinCode = function(code)
						self:JoinCode(code)
					end,
					OnJoinMatch = function(key)
						self:JoinMatch(key)
					end,
					OnBuyRobux = function(id)
						self:BuyRobux(id)
					end,
					OnBuyCoins = function(id)
						self:BuyCoins(id)
					end,
					OnEquipSkin = function(id)
						self:ToggleSkin(id)
					end,
					OnEquipDefault = function(gun)
						self:UnequipGun(gun)
					end,
					OnUseSkin = function(id)
						self:SetSkin(id)
					end,
					OnSelectGun = function(gun)
						self.CustomizeGun = gun
						self:InspectEquipped(gun)
					end,
					OnPreviewSkin = function(gun, id)
						self:Inspect(gun, id)
					end,
					OnRedeemCode = function(code)
						self:RedeemCode(code)
					end,
					OwnedSkins = function()
						return self.Dependencies.ProfileController.OwnedSkins()
					end,
					EquippedSkins = function()
						return self.Dependencies.ProfileController.EquippedSkins()
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
					Squad = function()
						return self:SquadOthers()
					end,
					CanKick = function()
						return self.Dependencies.PartyController:IsLeader()
					end,
					CanLeave = function()
						const party = self.Dependencies.PartyController
						return not party:IsLeader() and #party.Members() > 1
					end,
					OnKick = function(userId)
						self.Dependencies.PartyController:KickMember(userId)
					end,
					OnLeave = function()
						self.Dependencies.PartyController:LeaveSquad()
						self:Close()
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
	if not self.CameraCFrame then
		self.CameraCFrame = part.CFrame
	end
	camera.CFrame = self.CameraCFrame :: CFrame
end

function LobbyController:StepCamera(dt: number)
	const camera = workspace.CurrentCamera
	const part = self.CameraPart
	if not camera or not part then
		return
	end

	const base = (self.CameraCFrame or part.CFrame):Lerp(part.CFrame, 1 - math.exp(-dt * CAMERA_SMOOTH))
	self.CameraCFrame = base

	const viewport = camera.ViewportSize
	const mouse = UserInputService:GetMouseLocation()
	const target = if self.Inspecting then Vector2.zero else Vector2.new(
		math.clamp((mouse.X - viewport.X / 2) / (viewport.X / 2), -1, 1),
		math.clamp((mouse.Y - viewport.Y / 2) / (viewport.Y / 2), -1, 1)
	)
	const offset = self.MouseOffset:Lerp(target, 1 - math.exp(-dt * MOUSE_SMOOTH))
	self.MouseOffset = offset

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = base
		* CFrame.new(offset.X * MOUSE_MOVE, -offset.Y * MOUSE_MOVE, 0)
		* CFrame.Angles(-offset.Y * MOUSE_PITCH, -offset.X * MOUSE_YAW, 0)

	if self.Inspecting then
		self.Inspector.Update(dt, camera.CFrame)
	end
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
		RunService.RenderStepped:Connect(function(dt)
			if self.Active then
				self:StepCamera(dt)
			end
		end)
	)

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

function LobbyController:PreloadCosmetics()
	if self.CosmeticsPreloaded then
		return
	end
	self.CosmeticsPreloaded = true

	task.spawn(function()
		const player = Players.LocalPlayer
		const deadline = os.clock() + PRELOAD_WAIT
		while not player:GetAttribute(LOADING_DONE_ATTRIBUTE) and os.clock() < deadline do
			task.wait(PRELOAD_POLL)
		end

		const list: { any } = {}
		const assets = ReplicatedStorage:FindFirstChild("Assets")
		for _, name in PRELOAD_FOLDERS do
			const folder = if assets then assets:FindFirstChild(name) else nil
			if folder then
				table.insert(list, folder)
			end
		end
		for _, skin in SkinCatalog.Skins do
			table.insert(list, skin.Preview)
		end

		const ok, err = pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
		if not ok then
			warn(`[LobbyController] falha no preload de cosmeticos: {err}`)
		end
	end)
end

function LobbyController:EnterLobby()
	self.Active = true
	self.Token += 1
	const token = self.Token

	self:PreloadCosmetics()

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
	self.CameraCFrame = nil
	self.MouseOffset = Vector2.zero
	self.CurrentScreen("")
	self:SyncOthers()
	self:SyncStage()

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

function LobbyController:ClosePopup()
	const input = self.PopupInput
	self.PopupInput = nil
	if input then
		input:Disconnect()
	end

	const unmount = self.PopupUnmount
	self.PopupUnmount = nil
	if unmount then
		unmount()
	end
end

function LobbyController:ShowError(message: string, title: string?, success: boolean?)
	UISounds.Play(if success then "Open" else "Error")
	self:ClosePopup()

	const close = function()
		self:ClosePopup()
	end

	local popupGui: ScreenGui? = nil
	const unmountPopup = Vide.mount(function()
		popupGui = create("ScreenGui")({
			Name = "MatchErrorUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 100,

			create("TextButton")({
				Name = "Backdrop",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(43, 26, 14),
				BackgroundTransparency = POPUP_BACKDROP_TRANSPARENCY,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = "",
				Activated = close,
			}),

			ErrorPopup({
				Title = title or "Erro",
				Message = message,
				Success = success,
				OnClose = close,
			}),
		}) :: ScreenGui
		return popupGui
	end, Players.LocalPlayer:WaitForChild("PlayerGui"))

	self.PopupUnmount = function()
		unmountPopup()
		if popupGui then
			popupGui:Destroy()
		end
	end

	self.PopupInput = UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.Escape then
			close()
		end
	end)
end

LobbyController:OnInit(function(self)
	self:Setup()
end)

function LobbyController:BindReturnKey()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or input.KeyCode ~= RETURN_KEY then
			return
		end
		if self.Dependencies.GameStateController.State() == "Lobby" and self.CurrentScreen() ~= "" then
			self:Close()
		end
	end)
end

LobbyController:OnStart(function(self)
	self:BindReturnKey()
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
