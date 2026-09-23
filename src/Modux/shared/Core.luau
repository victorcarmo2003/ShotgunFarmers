--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ComponentManager = require(ReplicatedStorage.shared.Modux.ComponentManager)
local Loader = require(ReplicatedStorage.shared.Modux.Loader)
local Registry = require(ReplicatedStorage.shared.Modux.Classes.Registry)

export type DebugLevel = Loader.DebugLevel

export type Settings = {
	Profiling: boolean?,
	DebugLevel: DebugLevel?,
}

const Core = {}

function Core.Start(
	stores: { Loader.Store },
	templates: Registry.Templates,
	moduleScripts: { ModuleScript }?,
	settings: Settings?
)
	const s = (settings or {}) :: Settings
	const options: Loader.Options = {
		Profiling = s.Profiling == true,
		Debug = s.DebugLevel or "None",
	}

	const byId = Loader.prepare(stores, moduleScripts, options)
	ComponentManager.prepare(templates, byId, options)
	Loader.run(stores, options)
	ComponentManager.start()
end

function Core.Stop()
	ComponentManager.stop()
	Loader.stop()
end

return Core
