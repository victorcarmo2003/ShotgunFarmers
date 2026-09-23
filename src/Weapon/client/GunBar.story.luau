--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local GunBar = require(script.Parent.GunBar)

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		ActiveSlot = UILabs.Slider(1, 1, 3, 1),

		Ammo1 = UILabs.Slider(5, 0, 8, 1),
		MaxAmmo1 = 8,
		Image1 = "",

		Ammo2 = UILabs.Slider(4, 0, 4, 1),
		MaxAmmo2 = 4,
		Image2 = "",

		Ammo3 = UILabs.Slider(6, 0, 6, 1),
		MaxAmmo3 = 6,
		Image3 = "",
	},
}, function(props: UILabs.VideProps)
	local function slot(index: number): GunBar.SlotProps
		return {
			SlotNumber = tostring(index),
			Ammo = function()
				const current = props.controls[`Ammo{index}`]()
				const max = props.controls[`MaxAmmo{index}`]()
				return `{current}/{max}`
			end,
			IsActive = function()
				return props.controls.ActiveSlot() == index
			end,
			Image = function()
				return props.controls[`Image{index}`]()
			end,
			OnSelect = function()
				print(`WeaponSlot {index} selecionado`)
			end,
		}
	end

	return GunBar({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(220, 340),
		Slots = { slot(1), slot(2), slot(3) },
	})
end)
