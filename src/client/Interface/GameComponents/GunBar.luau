local StarterPlayer = game:GetService("StarterPlayer")
local WeaponSlot = require(script.Parent.WeaponSlot)
local Components = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Components)
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)

local Children = Fusion.Children

export type GunBarSlotValues = {
	SlotNumber: Fusion.StateObject<string> | string,
	Ammo: Fusion.StateObject<string> | string,
	Image: Fusion.StateObject<string> | string,
	IsActive: (Fusion.StateObject<boolean> | boolean)?,
	OnSelect: (() -> ())?,
}

export type GunBarValues = {
	Slot1: GunBarSlotValues,
	Slot2: GunBarSlotValues,
	Slot3: GunBarSlotValues,
}

return function(scope: Fusion.Scope, Values: GunBarValues)
	return Components.Frame(scope, {
		Name = "GunBar",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1.05, 0.55),
		Size = UDim2.fromScale(0.15, 0.5),
		BackgroundTransparency = 1,
		Visible = true,

		[Children] = {
			UIListLayout = Components.UIListLayout(scope, {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0.05, 0),
			}),

			Slot1 = WeaponSlot(scope, {
				LayoutOrder = 1,
			}, {
				SlotNumber = Values.Slot1.SlotNumber,
				Ammo = Values.Slot1.Ammo,
				IsActive = Values.Slot1.IsActive,
			}, Values.Slot1.Image, Values.Slot1.OnSelect),

			Slot2 = WeaponSlot(scope, {
				LayoutOrder = 2,
			}, {
				SlotNumber = Values.Slot2.SlotNumber,
				Ammo = Values.Slot2.Ammo,
				IsActive = Values.Slot2.IsActive,
			}, Values.Slot2.Image, Values.Slot2.OnSelect),

			Slot3 = WeaponSlot(scope, {
				LayoutOrder = 3,
			}, {
				SlotNumber = Values.Slot3.SlotNumber,
				Ammo = Values.Slot3.Ammo,
				IsActive = Values.Slot3.IsActive,
			}, Values.Slot3.Image, Values.Slot3.OnSelect),
		},
	})
end
