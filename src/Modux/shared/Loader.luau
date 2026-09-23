--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Registry = require(ReplicatedStorage.shared.Modux.Classes.Registry)
local Libs = require(ReplicatedStorage.shared.Modux.Libs)

export type Store = Registry.Store

export type DebugLevel = "Low" | "Medium" | "High"

export type Options = {
	Profiling: boolean,
	Debug: DebugLevel | "None",
}

local LIMITE: { [string]: number } = {
	None = math.huge,
	Low = 100,
	Medium = 1000 / 60,
	High = 1,
}

export type Tick = {
	instance: any,
	label: string,
	callback: (any, number) -> (),
	period: number,
	priority: number,
	seq: number,
	elapsed: number,
	dead: boolean,
}

export type TickHandle = { Tick }

local Loader = {}

local started = false
local bootStart = 0
local nextSeq = 0
local runtimeOptions: Options = { Profiling = false, Debug = "None" }
local modulesLoaded = 0
local perModule: { { name: string, ms: number } } = {}
local ticking: { Tick } = {}
local buryCount = 0
local heartbeat: RBXScriptConnection? = nil

local function indexById(stores: { Store }): { [string]: Registry.Entry }
	local byId = {}
	for _, store in stores do
		for _, entry in store do
			byId[entry.ID] = entry
		end
	end
	return byId
end

function Loader.resolve(
	owner: string,
	dependency: { string },
	byId: { [string]: Registry.Entry }
): { [string]: any }
	const dependencies = {}
	for _, id in dependency do
		const target = byId[id]
		if target == nil then
			const available = {}
			for other in byId do
				table.insert(available, other)
			end
			table.sort(available)
			error(
				`[Modux] "{owner}" requires "{id}", which is not registered. `
					.. `Registered: {table.concat(available, ", ")}`
			)
		end
		dependencies[id] = target.Class
	end
	return dependencies
end

local function inject(stores: { Store }, byId: { [string]: Registry.Entry })
	for _, store in stores do
		for _, entry in store do
			const instance = entry.Class :: any
			instance.Dependencies = Loader.resolve(entry.ID, entry.Dependency, byId)
			instance.Libs = Libs
		end
	end
end

local function ordered(stores: { Store }): { Registry.Entry }
	local all = {}
	for _, store in stores do
		for _, entry in store do
			table.insert(all, entry)
		end
	end
	table.sort(all, function(a: Registry.Entry, b: Registry.Entry)
		if a.Priority ~= b.Priority then
			return a.Priority > b.Priority
		end
		return a.ID < b.ID
	end)
	return all
end

function Loader.invoke(
	object: any,
	callbacks: { (any) -> () },
	phase: string,
	label: string,
	options: Options
)
	const limite = LIMITE[options.Debug] or math.huge
	for _, callback in callbacks do
		local previousCategory: string? = nil
		if options.Profiling then
			debug.profilebegin(`Modux.{phase}.{label}`)
			previousCategory = debug.getmemorycategory()
			debug.setmemorycategory(`Modux.{label}`)
		end
		const inicio = os.clock()
		const ok, err = pcall(callback, object)
		const ms = (os.clock() - inicio) * 1000
		if options.Profiling then
			if previousCategory ~= nil then
				debug.setmemorycategory(previousCategory)
			end
			debug.profileend()
		end
		if not ok then
			warn(`[Modux] {phase} of "{label}" errored: {err}`)
		elseif ms > limite then
			warn(`[Modux] {phase} of "{label}" took {string.format("%.1f", ms)} ms`)
		end
	end
end

local function fire(entries: { Registry.Entry }, phase: "OnInit" | "OnStart", options: Options)
	for _, entry in entries do
		const instance = entry.Class :: any
		Loader.invoke(instance, instance._registry[phase], phase, entry.ID, options)
	end
end

local function bury()
	if buryCount == 0 then
		return
	end
	local alive = {}
	for _, tick in ticking do
		if not tick.dead then
			table.insert(alive, tick)
		end
	end
	ticking = alive
	buryCount = 0
end

local function ensureClock()
	if heartbeat ~= nil then
		return
	end
	heartbeat = RunService.Heartbeat:Connect(function(delta: number)
		bury()
		for _, tick in ticking do
			if not tick.dead then
				tick.elapsed += delta
				if tick.elapsed >= tick.period then
					tick.elapsed %= tick.period

					local previousCategory: string? = nil
					if runtimeOptions.Profiling then
						debug.profilebegin(`Modux.OnTick.{tick.label}`)
						previousCategory = debug.getmemorycategory()
						debug.setmemorycategory(`Modux.{tick.label}`)
					end
					local ok, err = pcall(tick.callback, tick.instance, delta)
					if runtimeOptions.Profiling then
						if previousCategory ~= nil then
							debug.setmemorycategory(previousCategory)
						end
						debug.profileend()
					end
					if not ok then
						warn(`[Modux] OnTick errored: {err}`)
					end
				end
			end
		end
	end)
end

function Loader.addTicks(
	instance: any,
	ticks: { { callback: (any, number) -> (), tickRate: number, priority: number } },
	label: string
): TickHandle
	const handle: TickHandle = {}
	for _, tick in ticks do
		const row: Tick = {
			instance = instance,
			label = label,
			callback = tick.callback,
			period = 1 / math.max(tick.tickRate, 0.001),
			priority = tick.priority,
			seq = nextSeq,
			elapsed = 0,
			dead = false,
		}
		nextSeq += 1
		table.insert(ticking, row)
		table.insert(handle, row)
	end
	if #ticks > 0 then
		table.sort(ticking, function(a: Tick, b: Tick)
			if a.priority ~= b.priority then
				return a.priority > b.priority
			end
			return a.seq < b.seq
		end)
		ensureClock()
	end
	return handle
end

function Loader.removeTicks(handle: TickHandle)
	for _, tick in handle do
		if not tick.dead then
			tick.dead = true
			buryCount += 1
		end
	end
end

local function collectTicks(entries: { Registry.Entry })
	for _, entry in entries do
		const instance = entry.Class :: any
		Loader.addTicks(instance, instance._registry.OnTick, entry.ID)
	end
end

local loadOne = require :: (ModuleScript) -> any

local function loadModules(moduleScripts: { ModuleScript }, options: Options)
	const detalhado = options.Debug == "High"
	for _, moduleScript in moduleScripts do
		if detalhado then
			const inicio = os.clock()
			loadOne(moduleScript)
			table.insert(perModule, {
				name = moduleScript.Name,
				ms = (os.clock() - inicio) * 1000,
			})
		else
			loadOne(moduleScript)
		end
		modulesLoaded += 1
	end
end

function Loader.prepare(
	stores: { Store },
	moduleScripts: { ModuleScript }?,
	options: Options
): { [string]: Registry.Entry }
	if started then
		error("[Modux] Start was already called")
	end
	started = true
	bootStart = os.clock()
	runtimeOptions = options

	if moduleScripts then
		loadModules(moduleScripts, options)
	end

	const byId = indexById(stores)
	inject(stores, byId)
	return byId
end

function Loader.run(stores: { Store }, options: Options)
	if not started then
		error("[Modux] Loader.prepare must run before Loader.run")
	end

	const entries = ordered(stores)
	fire(entries, "OnInit", options)
	fire(entries, "OnStart", options)
	collectTicks(entries)

	if options.Debug ~= "None" then
		const total = (os.clock() - bootStart) * 1000
		local line = `[Modux] boot em {string.format("%.1f", total)} ms`
		if options.Debug ~= "Low" then
			line ..= ` | {#entries} singletons | {modulesLoaded} modulos requeridos`
		end
		print(line)
		if options.Debug == "High" then
			for _, m in perModule do
				print(`[Modux]   require {m.name}: {string.format("%.2f", m.ms)} ms`)
			end
		end
	end
end

function Loader.stop()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	table.clear(ticking)
	table.clear(perModule)
	nextSeq = 0
	buryCount = 0
	modulesLoaded = 0
	started = false
end

return Loader
