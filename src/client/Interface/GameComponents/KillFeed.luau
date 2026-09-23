local StarterPlayer = game:GetService("StarterPlayer")
local Component = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Components)
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local KillFeedEntry = require(script.Parent.KillFeedEntry)

local Children = Fusion.Children

export type KillFeedValues = {

	Entries: Fusion.StateObject<{ [number]: KillFeedEntry.KillFeedEntryValues }>,
}

return function(scope: Fusion.Scope, values: KillFeedValues)
	return Component.Frame(scope, {
		Name = "KillFeed",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.76, 0.4),
		Size = UDim2.fromScale(0.3, 0.6),
		BackgroundTransparency = 1,
		Visible = true,

		[Children] = {
			UIListLayout = Component.UIListLayout(scope, {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0.1, 0),
			}),

			Entries = scope:ForPairs(values.Entries, function(use, innerScope, id, entry)
				return id, KillFeedEntry(innerScope, entry)
			end),
		},
	})
end
