--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Funnels = require(ReplicatedStorage.shared.Analytics.Funnels)

export type Public = {
	Track: (self: Public, funnel: Funnels.FunnelName, step: string, detail: string?) -> (),
}

return {}
