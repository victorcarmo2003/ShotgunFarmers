local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)

return {
	name = "GameSelection",
	storyRoots = { script.Parent },
} :: UILabs.Storybook
