--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local vide = require(ReplicatedStorage.Packages.Vide)
local ReticleAmmo = require(StarterPlayer.StarterPlayerScripts.client.Weapon.ReticleAmmo)

return function(target)
	return vide.mount(function()
		local ammo = vide.source(12)
		task.spawn(function()
			while task.wait(0.4) do
				ammo(if ammo() <= 0 then 12 else ammo() - 1)
			end
		end)
		return ReticleAmmo({
			Ammo = ammo,
			MaxAmmo = function()
				return 12
			end,
			Visible = function()
				return true
			end,
		})
	end, target)
end
