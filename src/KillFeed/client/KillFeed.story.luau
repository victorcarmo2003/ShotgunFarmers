--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local KillFeed = require(script.Parent.KillFeed)

const create = Vide.create

const SHOTGUN = "rbxassetid://133680860540012"
const PEAVOLVER = "rbxassetid://106048482621476"

local function headshot(id: number): string
	return `rbxthumb://type=AvatarHeadShot&id={id}&w=48&h=48`
end

const OLD_KILLS: { KillFeed.Entry } = {
	{
		ShooterName = "Farmer99",
		ShooterImage = headshot(261),
		VictimName = "CornCob",
		VictimImage = headshot(1532),
		GunName = "Peavolver",
		GunImage = PEAVOLVER,
		IsHeadshot = false,
	},
	{
		ShooterName = "ShotgunSally",
		ShooterImage = headshot(3538),
		VictimName = "H4K0R",
		VictimImage = headshot(1),
		GunName = "Shotgun",
		GunImage = SHOTGUN,
		IsHeadshot = true,
	},
	{
		ShooterName = "CornCob",
		ShooterImage = headshot(1532),
		VictimName = "Farmer99",
		VictimImage = headshot(261),
		GunName = "Sniperagus",

		GunImage = "",
		IsHeadshot = false,
	},
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		IsHeadshot = true,
	},
}, function(props)
	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(24, 24, 28),

		KillFeed({
			Entries = function(): { KillFeed.Entry }
				const feed = table.clone(OLD_KILLS)
				table.insert(feed, 1, {
					ShooterName = "H4K0R",
					ShooterImage = headshot(1),
					VictimName = "dev_Hakor",
					VictimImage = headshot(156),
					GunName = "Shotgun",
					GunImage = SHOTGUN,

					IsHeadshot = props.controls.IsHeadshot(),
				})
				return feed
			end,
		}),
	})
end)
