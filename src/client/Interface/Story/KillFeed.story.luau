--!strict
local Fusion = require(script.Parent.Parent.Fusion)
local KillFeed = require(script.Parent.Parent.GameComponents.KillFeed)

local controls = {
	ShooterName = "H4K0R",
	VictimName = "dev_Hakor",
	GunName = "Shotgun",
	IsHeadshot = true,
}

type StoryProps = {
	scope: Fusion.Scope,
	target: Instance,
	controls: {
		ShooterName: Fusion.StateObject<string>,
		VictimName: Fusion.StateObject<string>,
		GunName: Fusion.StateObject<string>,
		IsHeadshot: Fusion.StateObject<boolean>,
	},
}

return {
	fusion = Fusion,
	controls = controls,
	story = function(props: StoryProps)
		local scope = props.scope

		-- Entrada 1 reage aos controles do UI Labs; 2 e 3 são fixas só pra dar contexto
		-- de empilhamento/espaçamento entre várias linhas ao mesmo tempo.
		local entries = scope:Computed(function(use)
			return {
				[1] = {
					LayoutOrder = -1,
					ShooterName = use(props.controls.ShooterName),
					ShooterImage = "",
					VictimName = use(props.controls.VictimName),
					VictimImage = "",
					GunName = use(props.controls.GunName),
					GunImage = "",
					IsHeadshot = use(props.controls.IsHeadshot),
				},
				[2] = {
					LayoutOrder = -2,
					ShooterName = "Farmer99",
					ShooterImage = "",
					VictimName = "CornCob",
					VictimImage = "",
					GunName = "Peavolver",
					GunImage = "",
					IsHeadshot = false,
				},
				[3] = {
					LayoutOrder = -3,
					ShooterName = "ShotgunSally",
					ShooterImage = "",
					VictimName = "H4K0R",
					VictimImage = "",
					GunName = "Shotgun",
					GunImage = "",
					IsHeadshot = true,
				},
			}
		end)

		local killFeed = KillFeed(scope, { Entries = entries })
		killFeed.Parent = props.target
		return killFeed
	end,
}
