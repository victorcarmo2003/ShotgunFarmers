--!strict
local Fusion = require(script.Parent.Parent.Fusion)
local Components = require(script.Parent.Parent.Components)

local controls = {
	Text = "00:30",
}

return {
	fusion = Fusion,
	controls = controls,
	story = function(props)
		return Components.TextLabel(props.scope, {
			Parent = props.target,
			Text = props.controls.Text,
		})
	end,
}
