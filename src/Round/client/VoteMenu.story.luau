--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local VoteMenu = require(StarterPlayer.StarterPlayerScripts.client.Round.VoteMenu)

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Seconds = 15,
		MyVote = 0,
		Winner = 0,
		HappyFarm = 3,
		WildWest = 1,
	},
}, function(props)
	return VoteMenu({
		Visible = function()
			return true
		end,
		Options = function()
			return {
				{ Name = "HappyFarm", DisplayName = "Happy Farm", Votes = props.controls.HappyFarm() },
				{ Name = "WildWest", DisplayName = "Wild West", Votes = props.controls.WildWest() },
			}
		end,
		MyVote = function()
			return props.controls.MyVote()
		end,
		Winner = function()
			return props.controls.Winner()
		end,
		Seconds = function()
			return props.controls.Seconds()
		end,
	})
end)
