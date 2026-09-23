--!strict

local Types = require(script.Parent.Parent.Types)

local Zones = {}
Zones.__index = Zones

function Zones.new(config: { isDynamic: boolean?, autoSync: boolean?, metadata: any? }?): Types.Zones
	local isDynamic = if config and config.isDynamic ~= nil then config.isDynamic else false
	local metadata = if config then config.metadata else nil
	local autoSync = if config and config.autoSync ~= nil then config.autoSync else false

	local self: Types.InternalZones = setmetatable({
		dynamic = isDynamic,
		metadata = metadata,
		autoSync = autoSync,
		zones = {} :: { [Types.Zone]: boolean },
		observers = {} :: { [Types.Observer<any>]: boolean },
		onDestroyObserverCleanups = {} :: { [Types.Observer<any>]: () -> () },
		onDestroyZoneCleanups = {} :: { [Types.Zone]: () -> () },
	}, Zones) :: any

	return self
end

function Zones.attach(self: Types.InternalZones, observer: Types.InternalObserver<any>): Types.Zones
	if self.observers[observer] then
		return self
	end
	self.observers[observer] = true

	self.onDestroyObserverCleanups[observer] = observer:onDestroy(function()
		self:detach(observer)
	end)

	for zone, _ in self.zones do
		zone:attach(observer)
	end

	return self
end

function Zones.detach(self: Types.InternalZones, observer: Types.InternalObserver<any>): Types.Zones
	if not self.observers[observer] then
		return self
	end
	self.observers[observer] = nil

	local cleanup = self.onDestroyObserverCleanups[observer]
	if cleanup then
		cleanup()
		self.onDestroyObserverCleanups[observer] = nil
	end

	for zone, _ in self.zones do
		zone:detach(observer)
	end
	return self
end

function Zones.sync(self: Types.InternalZones): Types.Zones
	if not self.dynamic then
		return self
	end
	for zone, _ in self.zones do
		zone:sync()
	end
	return self
end

function Zones.getZones(self: Types.InternalZones): { Types.Zone }
	local result = {}
	for zone, _ in self.zones do
		table.insert(result, zone)
	end
	return result
end

function Zones.isDynamic(self: Types.InternalZones): boolean
	return self.dynamic
end

function Zones.isPointInside(self: Types.InternalZones, point: Vector3): boolean
	for zone, _ in self.zones do
		if zone:isPointInside(point) then
			return true
		end
	end
	return false
end

function Zones.setAutoSync(self: Types.InternalZones, autoSync: boolean): Types.Zones
	if self.autoSync == autoSync then
		return self
	end

	self.autoSync = autoSync

	for zone, _ in self.zones do
		zone:setAutoSync(autoSync)
	end

	return self
end

function Zones.setDynamic(self: Types.InternalZones, isDynamic: boolean): Types.Zones
	if self.dynamic == isDynamic then
		return self
	end

	self.dynamic = isDynamic

	for zone, _ in self.zones do
		zone:setDynamic(isDynamic)
	end

	return self
end

function Zones.setMetadata(self: Types.InternalZones, metadata: any): Types.Zones
	self.metadata = metadata
	for zone, _ in self.zones do
		zone:setMetadata(metadata)
	end
	return self
end

function Zones.getMetadata(self: Types.InternalZones): any?
	return self.metadata
end

function Zones.contains(self: Types.InternalZones, zone: Types.Zone): boolean
	return self.zones[zone] == true
end

function Zones.iterZones(self: Types.InternalZones): () -> Types.Zone?
	local currentZone = nil
	return function(): Types.Zone?
		currentZone = next(self.zones, currentZone)
		return currentZone
	end
end

function Zones.onDestroy(self: Types.InternalZones, callback: () -> ()): () -> ()
	if not self.onDestroyCallbacks then
		self.onDestroyCallbacks = {}
	end

	table.insert(self.onDestroyCallbacks :: any, callback)

	return function()
		local idx = table.find(self.onDestroyCallbacks :: any, callback)
		if idx then
			table.remove(self.onDestroyCallbacks :: any, idx)
		end
	end
end

function Zones.destroy(self: Types.InternalZones)
	if self.onDestroyCallbacks then
		for _, callback in self.onDestroyCallbacks do
			task.spawn(callback)
		end
		table.clear(self.onDestroyCallbacks)
	end

	for _, cleanup in self.onDestroyObserverCleanups do
		cleanup()
	end

	for zone, cleanup in self.onDestroyZoneCleanups do
		cleanup()
		zone:destroy()
	end

	table.clear(self.zones)
	table.clear(self.observers)
	table.clear(self.onDestroyObserverCleanups)
	table.clear(self.onDestroyZoneCleanups)

	setmetatable(self :: any, nil)
end

function Zones.add(self: Types.InternalZones, zone: Types.Zone)
	if self.zones[zone] then
		return
	end

	if self.metadata ~= nil and zone:getMetadata() == nil then
		zone:setMetadata(self.metadata)
	end

	if self.dynamic and not zone:isDynamic() then
		zone:setDynamic(true)
	end

	if self.autoSync then
		zone:setAutoSync(true)
	end

	self.zones[zone] = true

	self.onDestroyZoneCleanups[zone] = zone:onDestroy(function()
		self:remove(zone)
	end)

	for observer, _ in self.observers do
		zone:attach(observer)
	end
end

function Zones.remove(self: Types.InternalZones, zone: Types.Zone)
	if not self.zones[zone] then
		return
	end
	self.zones[zone] = nil

	local cleanup = self.onDestroyZoneCleanups[zone]
	if cleanup then
		cleanup()
		self.onDestroyZoneCleanups[zone] = nil
	end

	for observer, _ in self.observers do
		zone:detach(observer)
	end
end

return Zones
