--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local vide = require(ReplicatedStorage.Packages.Vide)
local KillRanking = require(StarterPlayer.StarterPlayerScripts.client.Stats.KillRanking)

return function(target)
	return vide.mount(function()
		local entries = vide.source({
			{ UserId = 1, Kills = 3, Image = "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150", Team = "Red", IsLocal = false, Leader = true },
			{ UserId = 2, Kills = 3, Image = "rbxthumb://type=AvatarHeadShot&id=156&w=150&h=150", Team = "Red", IsLocal = true, Leader = true },
			{ UserId = 3, Kills = 2, Image = "", Team = "Blue", IsLocal = false, Leader = false },
			{ UserId = 4, Kills = 1, Image = "", Team = "Blue", IsLocal = false, Leader = false },
		})
		task.spawn(function()
			while task.wait(1.5) do
				local list = table.clone(entries())
				local first = table.clone(list[3])
				first.Kills += 1
				list[3] = first
				entries(list)
			end
		end)
		return KillRanking({
			Visible = function()
				return true
			end,
			Entries = entries,
			Teams = function()
				return true
			end,
			Red = function()
				return 3
			end,
			Blue = function()
				return 2
			end,
			LocalTeam = function()
				return "Red"
			end,
			Title = function()
				return "Standard"
			end,
		})
	end, target)
end
