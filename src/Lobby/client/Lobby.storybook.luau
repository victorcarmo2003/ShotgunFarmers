local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)

return {
	name = "Lobby",
	storyRoots = { script.Parent },
} :: UILabs.Storybook
