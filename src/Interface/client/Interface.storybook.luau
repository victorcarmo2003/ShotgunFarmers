local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)

return {
	name = "Interface",

	storyRoots = { script.Parent },
} :: UILabs.Storybook
