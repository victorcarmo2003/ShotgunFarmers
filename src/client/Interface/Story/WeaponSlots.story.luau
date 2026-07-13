local Fusion = require(script.Parent.Parent.Fusion)
local GunBar = require(script.Parent.Parent.GameComponents.GunBar)

local controls = {
	SlotNumber1 = "1",
	Ammo1 = 5,
	MaxAmmo1 = 8,
	Image1 = "",

	SlotNumber2 = "2",
	Ammo2 = 4,
	MaxAmmo2 = 4,
	Image2 = "",

	SlotNumber3 = "3",
	Ammo3 = 6,
	MaxAmmo3 = 6,
	Image3 = "",
}

return {
	fusion = Fusion,
	controls = controls,
	story = function(props)
		local scope = props.scope

		-- controles de munição vêm como números (atual/máximo); formata em texto reativo "atual/máximo"
		local function ammoText(current, max)
			return scope:Computed(function(use)
				return `{use(current)}/{use(max)}`
			end)
		end

		local Values = {
			Slot1 = {
				SlotNumber = props.controls.SlotNumber1,
				Ammo = ammoText(props.controls.Ammo1, props.controls.MaxAmmo1),
				Image = props.controls.Image1,
			},
			Slot2 = {
				SlotNumber = props.controls.SlotNumber2,
				Ammo = ammoText(props.controls.Ammo2, props.controls.MaxAmmo2),
				Image = props.controls.Image2,
			},
			Slot3 = {
				SlotNumber = props.controls.SlotNumber3,
				Ammo = ammoText(props.controls.Ammo3, props.controls.MaxAmmo3),
				Image = props.controls.Image3,
			},
		}

		local gunBar = GunBar(scope, Values)
		gunBar.Parent = props.target
		return gunBar
	end,
}
