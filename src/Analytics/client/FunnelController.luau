--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Funnels = require(ReplicatedStorage.shared.Analytics.Funnels)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const FunnelController = Modux.Controller("FunnelController", { Priority = 900 })

function FunnelController:Track(funnel: Funnels.FunnelName, step: string, detail: string?)
	self.Libs.Net.Analytics.Track:fireServer({
		Funnel = funnel,
		Step = step,
		Detail = string.sub(detail or "", 1, 32),
	})
end

return FunnelController
