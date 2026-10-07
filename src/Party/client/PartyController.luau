--!strict
local Players = game:GetService "Players"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local RunService = game:GetService "RunService"
local StarterPlayer = game:GetService "StarterPlayer"
local UserInputService = game:GetService "UserInputService"
local PartyNet = require(ReplicatedStorage.shared.Party.Net)
local PartySettings = require(ReplicatedStorage.shared.Party.PartySettings)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local InviteCircle = require(StarterPlayer.StarterPlayerScripts.client.Lobby.Element.InviteCircle)
local InvitePopup = require(StarterPlayer.StarterPlayerScripts.client.Party.InvitePopup)

const create = Vide.create
const source = Vide.source

const LOBBY_WAIT = 30
const BILLBOARD_SIZE = UDim2.fromScale(3, 3.6)
const BILLBOARD_OFFSET = Vector3.new(0, 3.5, 0)
const IN_GAME_LOCATION = 4

type Invite = {
	Id: string,
	From: number,
	FromName: string,
	Started: number,
	Duration: number,
}

const PartyController = Modux.Controller("PartyController", {
	Require = { "GameStateController" },
	Priority = 452,
})

function PartyController:Setup()
	self.Leader = source(0) :: Vide.Source<number>
	self.Members = source({} :: { PartyNet.Member }) :: Vide.Source<{ PartyNet.Member }>
	self.Friends = source({} :: { PartyNet.Friend }) :: Vide.Source<{ PartyNet.Friend }>
	self.Sent = source({} :: { [number]: boolean }) :: Vide.Source<{ [number]: boolean }>
	self.Loading = source(false) :: Vide.Source<boolean>
	self.Current = source(false :: Invite | false) :: Vide.Source<Invite | false>
	self.Progress = source(1) :: Vide.Source<number>
	self.Queue = {} :: { Invite }
	self.Timer = nil :: RBXScriptConnection?
	self.Notice = self.Libs.Signal.new() :: SignalLib.Signal<string>
	self.InviteRequested = self.Libs.Signal.new() :: SignalLib.Signal<>
end

function PartyController:MemberAt(slot: number): PartyNet.Member?
	for _, member in self.Members() do
		if member.Slot == slot then
			return member
		end
	end
	return nil
end

function PartyController:IsLeader(): boolean
	return self.Leader() == Players.LocalPlayer.UserId
end

function PartyController:Candidates(): { number }
	const candidates: { number } = {}
	const ok, online = pcall(function(): any
		return Players.LocalPlayer:GetFriendsOnlineAsync(200)
	end)
	if not ok or typeof(online) ~= "table" then
		return candidates
	end

	for _, entry in online do
		if typeof(entry) ~= "table" or typeof(entry.VisitorId) ~= "number" then
			continue
		end

		const placeId = entry.PlaceId
		const inThisGame = placeId == game.PlaceId
		const unknownGame = placeId == nil and entry.LocationType == IN_GAME_LOCATION
		if (inThisGame or unknownGame) and #candidates < PartySettings.MaxCandidates then
			table.insert(candidates, entry.VisitorId)
		end
	end
	return candidates
end

function PartyController:LoadFriends(): { PartyNet.Friend }
	self.Loading(true)
	const candidates = self:Candidates()
	local entries: { PartyNet.Friend } = {}

	if #candidates > 0 then
		const ok, reply = self.Libs.Net.Party.Friends:request({ Candidates = candidates }, PartySettings.QueryTimeout)
		if ok and typeof(reply) == "table" then
			entries = (reply :: { Entries: { PartyNet.Friend } }).Entries
		end
	end

	self.Friends(entries)
	self.Loading(false)
	return entries
end

function PartyController:MarkSent(userId: number, sent: boolean)
	const current = table.clone(self.Sent())
	current[userId] = if sent then true else nil
	self.Sent(current)
end

function PartyController:Invite(userId: number): (boolean, string)
	if self.Sent()[userId] then
		return false, "Invite already sent"
	end

	self:MarkSent(userId, true)
	const ok, reply = self.Libs.Net.Party.Invite:request({ UserId = userId }, PartySettings.QueryTimeout)
	if not ok or typeof(reply) ~= "table" then
		self:MarkSent(userId, false)
		return false, "The server did not respond, try again"
	end

	const answer = reply :: { Accepted: boolean, Reason: string }
	if not answer.Accepted then
		self:MarkSent(userId, false)
		return false, answer.Reason
	end

	task.delay(PartySettings.InviteDuration, function()
		self:MarkSent(userId, false)
	end)
	return true, ""
end

function PartyController:StopTimer()
	if self.Timer then
		self.Timer:Disconnect()
		self.Timer = nil
	end
end

function PartyController:ShowNext()
	self:StopTimer()

	while #self.Queue > 0 do
		const invite = table.remove(self.Queue, 1) :: Invite
		if os.clock() - invite.Started < invite.Duration then
			self.Current(invite)
			self.Progress(1)
			self.Timer = RunService.Heartbeat:Connect(function()
				const elapsed = os.clock() - invite.Started
				const remaining = 1 - elapsed / math.max(invite.Duration, 1)
				if remaining <= 0 then
					self.Current(false)
					self:ShowNext()
					return
				end
				self.Progress(remaining)
			end)
			return
		end
	end

	self.Current(false)
end

function PartyController:Respond(accept: boolean)
	const invite = self.Current()
	if not invite then
		return
	end

	self.Libs.Net.Party.Respond:fireServer { Id = invite.Id, Accept = accept }
	self.Current(false)
	self:ShowNext()
end

function PartyController:Enqueue(data: { Id: string, From: number, FromName: string, Seconds: number })
	for index, queued in self.Queue do
		if queued.From == data.From then
			table.remove(self.Queue, index)
			break
		end
	end

	table.insert(self.Queue, {
		Id = data.Id,
		From = data.From,
		FromName = data.FromName,
		Started = os.clock(),
		Duration = data.Seconds,
	})

	const current = self.Current()
	if not current then
		self:ShowNext()
	elseif current.From == data.From then
		self.Current(false)
		self:ShowNext()
	end
end

function PartyController:MountPopup()
	Vide.mount(function()
		return create "ScreenGui" {
			Name = "PartyInviteUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 90,

			InvitePopup {
				Visible = function()
					return self.Current() ~= false
				end,
				UserId = function()
					const current = self.Current()
					return if current then current.From else 0
				end,
				Name = function()
					const current = self.Current()
					return if current then current.FromName else ""
				end,
				Progress = function()
					return self.Progress()
				end,
				OnAccept = function()
					self:Respond(true)
				end,
				OnDecline = function()
					self:Respond(false)
				end,
			},
		}
	end, Players.LocalPlayer:WaitForChild "PlayerGui")
end

function PartyController:SlotPart(slot: number): BasePart?
	const lobby = workspace:FindFirstChild "Lobby"
	const positions = if lobby then lobby:FindFirstChild "CharacterPositions" else nil
	const part = if positions then positions:FindFirstChild(tostring(slot)) else nil
	return if part and part:IsA "BasePart" then part else nil
end

function PartyController:Billboard(slot: number, lobbyRoot: () -> Instance | false): BillboardGui
	const gameState = self.Dependencies.GameStateController

	const member = function(): PartyNet.Member?
		return self:MemberAt(slot)
	end

	return create "BillboardGui" {
		Name = `SquadSlot{slot}`,
		Size = BILLBOARD_SIZE,
		StudsOffsetWorldSpace = BILLBOARD_OFFSET,
		AlwaysOnTop = true,
		Active = true,
		ResetOnSpawn = false,
		Adornee = function(): any
			lobbyRoot()
			return self:SlotPart(slot)
		end,
		Enabled = function()
			if gameState.State() ~= "Lobby" or not lobbyRoot() then
				return false
			end
			const current = member()
			return current == nil or current.Status ~= "Present"
		end,

		InviteCircle {
			Image = function()
				const current = member()
				return if current then `rbxthumb://type=AvatarHeadShot&id={current.UserId}&w=150&h=150` else ""
			end,
			Caption = function()
				const current = member()
				if not current then
					return ""
				elseif current.Status == "Idle" then
					return "IDLE"
				elseif current.Status == "Joining" then
					return "JOINING"
				end
				return "IN MATCH"
			end,
			Activated = function()
				if member() == nil then
					self.InviteRequested:Fire()
				end
			end,
		},
	}
end

function PartyController:MountBillboards()
	const lobbyRoot = source(workspace:FindFirstChild "Lobby" or false) :: Vide.Source<Instance | false>
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Lobby" then
			lobbyRoot(child)
		end
	end)
	workspace.ChildRemoved:Connect(function(child)
		if child == lobbyRoot() then
			lobbyRoot(workspace:FindFirstChild "Lobby" or false)
		end
	end)

	if not lobbyRoot() then
		const found = workspace:WaitForChild("Lobby", LOBBY_WAIT)
		if found then
			lobbyRoot(found)
		end
	end

	const playerGui = Players.LocalPlayer:WaitForChild "PlayerGui"
	for slot = 2, PartySettings.MaxSize do
		Vide.mount(function()
			return self:Billboard(slot, lobbyRoot)
		end, playerGui)
	end
end

function PartyController:BindKeys()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or self.Current() == false then
			return
		end

		if input.KeyCode == Enum.KeyCode.Y then
			self:Respond(true)
		elseif input.KeyCode == Enum.KeyCode.N then
			self:Respond(false)
		end
	end)
end

PartyController:OnInit(function(self)
	self:Setup()

	const net = self.Libs.Net.Party

	net.State:onClient(function(state)
		Vide.batch(function()
			self.Leader(state.Leader)
			self.Members(state.Members)
		end)
	end)

	net.Invited:onClient(function(data)
		self:Enqueue(data)
	end)

	net.Resolved:onClient(function(data)
		self:MarkSent(data.UserId, false)
	end)

	net.Notice:onClient(function(data)
		self.Notice:Fire(data.Message)
	end)
end)

PartyController:OnStart(function(self)
	self:BindKeys()

	task.spawn(function()
		self:MountPopup()
	end)

	task.spawn(function()
		self:MountBillboards()
	end)
end)

return PartyController
