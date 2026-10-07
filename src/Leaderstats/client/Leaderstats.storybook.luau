local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)

return {
	name = "Leaderstats",
	storyRoots = { script.Parent },
} :: UILabs.Storybook
