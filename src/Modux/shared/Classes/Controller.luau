--!strict
const Controller = {}
Controller.__index = Controller

export type Registry = {
	OnInit: { (any) -> () },
	OnStart: { (any) -> () },
	OnTick: { { callback: (any) -> (), tickRate: number, priority: number } },
}

function Controller:OnTick(callback, tickRate: number?, priority: number?)
	const onTickList = self._registry.OnTick
	if type(callback) ~= "function" then
		error(`[OnTick] Must be callback function, got {type(callback)}`)
	end
	table.insert(onTickList, {
		callback = callback,
		tickRate = tickRate or 1,
		priority = priority or 1,
	})
end

function Controller:OnInit(callback)
	const onInitList = self._registry.OnInit
	if type(callback) ~= "function" then
		error(`[OnInit] Must be callback function, got {type(callback)}`)
	end
	table.insert(onInitList, callback)
end

function Controller:OnStart(callback)
	const onStartList = self._registry.OnStart
	if type(callback) ~= "function" then
		error(`[OnStart] Must be callback function, got {type(callback)}`)
	end
	table.insert(onStartList, callback)
end

function Controller.New()
	return setmetatable({
		_registry = {
			OnInit = {},
			OnStart = {},
			OnTick = {},
		} :: Registry,
	}, { __index = Controller })
end

return Controller
