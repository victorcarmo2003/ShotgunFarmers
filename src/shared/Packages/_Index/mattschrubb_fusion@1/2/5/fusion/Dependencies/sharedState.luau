--!strict

local Package = script.Parent.Parent
local PubTypes = require(Package.PubTypes)

type Set<T> = { [T]: any }

local dependencySet: Set<PubTypes.Dependency>? = nil

local initialisedStack: { Set<PubTypes.Dependency> } = {}
local initialisedStackSize = 0

return {
	dependencySet = dependencySet,
	initialisedStack = initialisedStack,
	initialisedStackSize = initialisedStackSize,
}
