--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local MatchmakingNet = require(ReplicatedStorage.shared.Matchmaking.Net)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local RoomCodeLabel = require(StarterPlayer.StarterPlayerScripts.client.Matchmaking.RoomCodeLabel)

type PlayMode = MatchmakingNet.PlayMode
type State = MatchmakingNet.State
type Room = MatchmakingNet.Room
type RoomMode = MatchmakingNet.RoomMode

const ROOM_CODE_ATTRIBUTE = "RoomCode"

const NO_REPLY = "O servidor nao respondeu, tente novamente"

local function answerOf(ok: boolean, reply: any): (boolean, string)
	if not ok or typeof(reply) ~= "table" then
		return false, NO_REPLY
	end

	const answer = reply :: { Accepted: boolean, Reason: string }
	return answer.Accepted, answer.Reason
end

const MatchmakingController = Modux.Controller("MatchmakingController", { Priority = 455 })

function MatchmakingController:Setup()
	self.State = Vide.source("Idle" :: State) :: Vide.Source<State>
	self.Reason = Vide.source("") :: Vide.Source<string>
	self.Failed = self.Libs.Signal.new() :: SignalLib.Signal<string>
	self.Rooms = Vide.source({} :: { Room }) :: Vide.Source<{ Room }>
	self.RoomsLoading = Vide.source(false) :: Vide.Source<boolean>
	self.RoomCode = Vide.source("") :: Vide.Source<string>
end

function MatchmakingController:SyncRoomCode()
	const code = workspace:GetAttribute(ROOM_CODE_ATTRIBUTE)
	self.RoomCode(if typeof(code) == "string" then code else "")
end

function MatchmakingController:MountRoomCode()
	self:SyncRoomCode()
	workspace:GetAttributeChangedSignal(ROOM_CODE_ATTRIBUTE):Connect(function()
		self:SyncRoomCode()
	end)

	Vide.mount(function()
		return Vide.create("ScreenGui")({
			Name = "RoomCodeUI",
			ResetOnSpawn = false,
			DisplayOrder = 5,

			RoomCodeLabel({ Code = self.RoomCode }),
		})
	end, Players.LocalPlayer:WaitForChild("PlayerGui"))
end

function MatchmakingController:IsBusy(): boolean
	const state = self.State()
	return state == "Searching" or state == "Teleporting"
end

function MatchmakingController:Play(mode: PlayMode): (boolean, string)
	const ok, reply = self.Libs.Net.Matchmaking.Play:request({ Mode = mode })
	return answerOf(ok, reply)
end

function MatchmakingController:CreateRoom(mode: RoomMode, mapName: string, private: boolean): (boolean, string)
	const ok, reply = self.Libs.Net.Matchmaking.CreateRoom:request({ Mode = mode, Map = mapName, Private = private })
	return answerOf(ok, reply)
end

function MatchmakingController:JoinRoom(code: string): (boolean, string)
	const ok, reply = self.Libs.Net.Matchmaking.JoinRoom:request({ Code = string.sub(code, 1, 8) })
	return answerOf(ok, reply)
end

function MatchmakingController:JoinMatch(key: string): (boolean, string)
	const ok, reply = self.Libs.Net.Matchmaking.JoinMatch:request({ Key = key })
	return answerOf(ok, reply)
end

function MatchmakingController:RefreshRooms()
	if self.RoomsLoading() then
		return
	end

	self.RoomsLoading(true)
	task.spawn(function()
		const ok, reply = self.Libs.Net.Matchmaking.ListRooms:request(nil)
		if ok and typeof(reply) == "table" then
			self.Rooms((reply :: { Rooms: { Room } }).Rooms)
		end
		self.RoomsLoading(false)
	end)
end

function MatchmakingController:Cancel()
	self.Libs.Net.Matchmaking.Cancel:fireServer()
end

function MatchmakingController:ReturnToLobby()
	if self:IsBusy() then
		return
	end

	self.Libs.Net.Matchmaking.ReturnToLobby:fireServer()
end

MatchmakingController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Matchmaking.Status:onClient(function(status)
		const state = status.State :: State
		Vide.batch(function()
			self.State(state)
			self.Reason(status.Reason)
		end)

		if state == "Failed" then
			self.Failed:Fire(if status.Reason ~= "" then status.Reason else "Falha no matchmaking")
		end
	end)
end)

MatchmakingController:OnStart(function(self)
	self:MountRoomCode()
end)

return MatchmakingController
