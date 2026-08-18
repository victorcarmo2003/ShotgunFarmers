local StarterPlayer = game:GetService("StarterPlayer")
local Component = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Components)
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local TableMerge = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Utils.TableMerge)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local INACTIVE_COLOR = Color3.new(0.12549, 0.12549, 0.12549)
local ACTIVE_COLOR = Color3.new(0.35, 0.32, 0.14)

export type weaponSlotProps = {
	Name: string?,
	LayoutOrder: number?,
	Visible: boolean?,
	Size: UDim2?,
} & { any }

export type WeaponSlotValues = {
	SlotNumber: Fusion.StateObject<string> | string,
	Ammo: Fusion.StateObject<string> | string,
	IsActive: (Fusion.StateObject<boolean> | boolean)?,
}

return function(
	scope: Fusion.Scope,
	props: weaponSlotProps,
	values: WeaponSlotValues,
	ImageID: Fusion.StateObject<string> | string,
	onSelect: (() -> ())?
)
	local backgroundColor = scope:Computed(function(use)
		local isActive = values.IsActive ~= nil and use(values.IsActive :: any)
		return if isActive then ACTIVE_COLOR else INACTIVE_COLOR
	end)

	local defaultProps = {
		Name = "WeaponSlot",
		Size = UDim2.fromScale(0.6, 0.2),
		BackgroundColor3 = scope:Spring(backgroundColor, 20, 1),
		BackgroundTransparency = 0,
		Visible = true,
		Active = true,

		[OnEvent("InputBegan")] = function(input: InputObject)
			if not onSelect then
				return
			end
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				onSelect()
			end
		end,

		[Children] = {
			SlotNumber = Component.TextLabel(scope, {
				Name = "SlotNumber",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromScale(0.25, 0.3),
				TextSize = 20,
				Text = values.SlotNumber,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextYAlignment = Enum.TextYAlignment.Top,
				ZIndex = 2,
			}),

			WeaponImage = Component.ImageLabel(scope, {
				Name = "WeaponImage",
				Size = UDim2.fromScale(0.8, 0.8),
				BackgroundTransparency = 1,
				Image = ImageID or "",
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 1,
			}),

			Ammo = Component.TextLabel(scope, {
				Name = "Ammo",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromScale(0.9, 0.9),
				Size = UDim2.fromScale(0.6, 0.4),
				BackgroundTransparency = 1,
				Text = values.Ammo,
				TextSize = 22,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextYAlignment = Enum.TextYAlignment.Bottom,
				ZIndex = 2,
			}),
		},
	}

	return Component.Frame(scope, TableMerge(defaultProps, props))
end
