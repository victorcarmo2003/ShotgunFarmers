--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local MatchmakingNet = require(ReplicatedStorage.shared.Matchmaking.Net)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

type PlayMode = MatchmakingNet.PlayMode
type State = MatchmakingNet.State

const MatchmakingController = Modux.Controller("MatchmakingController", { Priority = 455 })

function MatchmakingController:Setup()
	self.State = Vide.source("Idle" :: State) :: Vide.Source<State>
	self.Reason = Vide.source("") :: Vide.Source<string>
	self.Failed = self.Libs.Signal.new() :: SignalLib.Signal<string>
end

function MatchmakingController:IsBusy(): boolean
	const state = self.State()
	return state == "Searching" or state == "Teleporting"
end

function MatchmakingController:Play(mode: PlayMode): (boolean, string)
	const ok, reply = self.Libs.Net.Matchmaking.Play:request({ Mode = mode })
	if not ok or typeof(reply) ~= "table" then
		return false, "O servidor nao respondeu, tente novamente"
	end

	const answer = reply :: { Accepted: boolean, Reason: string }
	return answer.Accepted, answer.Reason
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

return MatchmakingController
