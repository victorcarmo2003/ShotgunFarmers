--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local conch = require(ReplicatedStorage.Packages.Conch)

local function gunNames(): { string }
	const names = {}
	for name in GetGun.All do
		table.insert(names, name)
	end

	return names
end

return {
	GunName = conch.args.enum_from_array("gun_name", gunNames()),
}
