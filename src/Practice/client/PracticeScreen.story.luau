--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local PracticeCatalog = require(ReplicatedStorage.shared.Practice.PracticeCatalog)
local vide = require(ReplicatedStorage.Packages.Vide)
local PracticeScreen = require(StarterPlayer.StarterPlayerScripts.client.Practice.PracticeScreen)

return function(target)
	return vide.mount(function()
		local equipped = vide.source({ 101, 111, 121 })
		local ammo = vide.source(false)
		local grenades = vide.source(true)

		return PracticeScreen({
			Visible = function()
				return true
			end,
			Equipped = equipped,
			InfiniteAmmo = ammo,
			InfiniteGrenades = grenades,
			OnSelect = function(id)
				local entry = PracticeCatalog.ByID[id]
				if entry then
					local slots = table.clone(equipped())
					slots[entry.Slot] = id
					equipped(slots)
				end
			end,
			OnToggleAmmo = function()
				ammo(not ammo())
			end,
			OnToggleGrenades = function()
				grenades(not grenades())
			end,
		})
	end, target)
end
