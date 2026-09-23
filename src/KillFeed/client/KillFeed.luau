--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local KillFeedEntry = require(script.Parent.KillFeedEntry)

const create = Vide.create
const values = Vide.values

export type Entry = KillFeedEntry.Entry

export type Props = {
	Entries: () -> { Entry },
	Name: string?,
	Position: UDim2?,
	Size: UDim2?,
}

return function(props: Props): Frame
	return create("Frame")({
		Name = props.Name or "KillFeed",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.76, 0.4),
		Size = props.Size or UDim2.fromScale(0.3, 0.6),
		BackgroundTransparency = 1,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0.1, 0),
		}),

		values(props.Entries, function(entry: Entry, index: () -> number)
			return KillFeedEntry({ Entry = entry, LayoutOrder = index })
		end),
	})
end
