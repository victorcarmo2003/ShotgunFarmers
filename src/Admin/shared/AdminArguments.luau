--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local GoldenAppleSettings = require(ReplicatedStorage.shared.GoldenApple.GoldenAppleSettings)
local conch = require(ReplicatedStorage.Packages.Conch)

local function gunNames(): { string }
	const names = {}
	for name in GetGun.All do
		table.insert(names, name)
	end

	return names
end

local function seedNames(): { string }
	const names = { GoldenAppleSettings.ASSET_NAME }
	for name, gunData in GetGun.All do
		if not gunData.Disabled and gunData.SeedModel ~= "" then
			table.insert(names, name)
		end
	end

	return names
end

return {
	GunName = conch.args.enum_from_array("gun_name", gunNames()),
	SeedName = conch.args.enum_from_array("seed", seedNames()),
}
