--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetThumbnail = require(ReplicatedStorage.Shared.Utils.GetThumbnail)
local Fusion = require(script.Parent.Parent.Fusion)
local HealthBar = require(script.Parent.Parent.GameComponents.StatusBar)

local controls = {
	Health = 100,
	Armor = 100,
	PlayerImage = GetThumbnail.AvatarBurst(game.Players.dev_Hakor),
}

type StoryProps = {
	scope: Fusion.Scope,
	target: Instance,
	controls: {
		Health: Fusion.StateObject<number>,
		Armor: Fusion.StateObject<number>,
	},
}

return {
	fusion = Fusion,
	controls = controls,
	story = function(props: StoryProps)
		local scope = props.scope

		local Values = {
			Health = scope:Computed(function(use)
				return use(props.controls.Health) / 100
			end),
			Armor = scope:Computed(function(use)
				return use(props.controls.Armor) / 100
			end),
		}

		local statusBar = HealthBar(scope, Values)
		statusBar.Parent = props.target
		return statusBar
	end,
}
