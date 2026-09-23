--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local WeaponSlot = require(script.Parent.WeaponSlot)

const create = Vide.create

export type SlotProps = WeaponSlot.Props

export type Props = {
	Slots: { SlotProps },
	Name: string?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,
}

return function(props: Props): Frame
	const children = {} :: { Instance }

	table.insert(
		children,
		create("UIListLayout")({
			Name = "UIList",
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.05, 0),
		})
	)

	for index, slot in props.Slots do
		const slotProps = table.clone(slot)
		slotProps.LayoutOrder = index
		table.insert(children, WeaponSlot(slotProps))
	end

	return create("Frame")({
		Name = props.Name or "GunBar",
		AnchorPoint = props.AnchorPoint or Vector2.new(1, 0),
		Position = props.Position or UDim2.fromScale(1.05, 0.55),
		Size = props.Size or UDim2.fromScale(0.15, 0.5),
		BackgroundTransparency = 1,

		children,
	})
end
