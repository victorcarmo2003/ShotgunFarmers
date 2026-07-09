--!strict
local Fusion = require(script.Parent.Parent.Fusion)
local HealthBar = require(script.Parent.Parent.GameComponents.StatusBar)

local controls = {
	Text = "100",
}

return {
	fusion = Fusion,
	controls = controls,
	story = function(props)
		return HealthBar(props.scope)
	end,
}