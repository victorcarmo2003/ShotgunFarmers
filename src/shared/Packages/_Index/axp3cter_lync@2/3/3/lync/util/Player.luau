--!strict
--!optimize 2

local Player = {}

function Player.is(value: any): boolean
	return typeof(value) == "Instance" and value:IsA("Player")
end

return table.freeze(Player)
