local StarterPlayer = game:GetService("StarterPlayer")
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local Modux = require(game.ReplicatedStorage.Shared.Modux)

local RoundController = Modux.Controller("RoundController"):Import("InterfaceController")
type Self = typeof(RoundController)

local _STATE_LABELS = {
	Starting = "Preparando",
	Match = "Partida",
	Intermission = "Intervalo",
	Vote = "Votação",
}

local function formatSeconds(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

RoundController.SetupLabel = function(self: Self)
	self.Label = self.InterfaceController.MainGui.TimerLabel
end

RoundController.UpdateLabel = function(self: Self)
	local stateName = self.CurrentState
	local text = `{stateName}  {formatSeconds(self.Scope.peek(self.CurrentTimer))}`
	self.Text:set(text)

	if self.Label then
		self.Label.Text = text
	end
end

RoundController:OnInit(function(self)
	local scoped = Fusion.scoped(Fusion)
	self.Scope = scoped
	self.Text = scoped:Value("Carregando...")
	self.CurrentTimer = scoped:Value(0) :: Fusion.Value<number>
	self.CurrentState = "Starting"

	self.Network.Packages.RoundState:on(function(data: { State: string, Seconds: number })
		self.CurrentState = data.State
		self.CurrentTimer:set(data.Seconds)
		self:UpdateLabel()
	end)
end)

RoundController:OnStart(function(self)
	self:SetupLabel()
	self:UpdateLabel()
end)

return RoundController
