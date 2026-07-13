local StarterPlayer = game:GetService("StarterPlayer")
local Component = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Components)
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local KillFeedEntry = require(script.Parent.KillFeedEntry)

local Children = Fusion.Children

export type KillFeedValues = {
	-- Mapa id único -> dados da entrada (ver KillFeedController.PushEntry) -- chave por id
	-- em vez de índice de array pra cada linha manter identidade estável entre re-renders.
	Entries: Fusion.StateObject<{ [number]: KillFeedEntry.KillFeedEntryValues }>,
}

return function(scope: Fusion.Scope, values: KillFeedValues)
	return Component.Frame(scope, {
		Name = "KillFeed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.98, 0.05),
		Size = UDim2.fromScale(0.55, 0.4),
		BackgroundTransparency = 1,
		Visible = true,

		[Children] = {
			UIListLayout = Component.UIListLayout(scope, {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),

			Entries = scope:ForPairs(values.Entries, function(use, innerScope, id, entry)
				return id, KillFeedEntry(innerScope, entry)
			end),
		},
	})
end
