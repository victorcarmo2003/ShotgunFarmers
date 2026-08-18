--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Parent.Config)
local State = require(script.Parent.Parent.Core.State)
local Types = require(script.Parent.Parent.Types)
local Geometry = require(script.Parent.Parent.Utils.Geometry)

local isPointInShape = Geometry.isPointInShape

local dirtyProfiles = State.dirtyProfiles
local dirtyTopology = State.dirtyTopology
local zoneAttachedObservers = State.zoneAttachedObservers

local staticCFrames = State.staticCFrames
local staticHalfSizes = State.staticHalfSizes
local staticTypes = State.staticTypes
local dynamicCFrames = State.dynamicCFrames
local dynamicHalfSizes = State.dynamicHalfSizes
local dynamicTypes = State.dynamicTypes
local dynamicTree = State.dynamicTree
local staticTree = State.staticTree

local IS_CLIENT = RunService:IsClient()

local function updateAllEntitiesForObserver(observerId: number)
	for groupId, observers in State.groupToObservers do
		if not observers[observerId] then
			continue
		end

		local group = State.groups[groupId]
		if not group then
			continue
		end

		for _, entity in group.entities do
			dirtyProfiles[entity] = true
			dirtyTopology[entity] = true
		end
	end
end

local function disconnectObserverFromGroup(observerId: number, group: Types.InternalGroup<any>)
	local safety = State.observerSafety[observerId]

	for _, entity in group.entities do
		local data = State.entityData[entity]
		if not data then
			continue
		end

		dirtyProfiles[entity] = true
		dirtyTopology[entity] = true

		local activeObservers = State.entityToObservers[entity] or {}
		local oldZoneId = data.activeObserverMemberships[observerId]

		if not oldZoneId or activeObservers[observerId] then
			continue
		end

		data.activeObserverMemberships[observerId] = nil
		if State.observerTrackingEntities[observerId] then
			State.observerTrackingEntities[observerId][entity] = nil
		end

		local cbs = State.observerExitedCallbacks[observerId]
		if not cbs then
			continue
		end

		local z = State.zoneIdToZoneObj[oldZoneId]
		local ref = State.entityToReference[entity] or entity
		for _, fn in cbs do
			if safety then
				task.spawn(fn, ref, z)
			else
				fn(ref, z)
			end
		end
	end
end

local Observer = {}
Observer.__index = Observer

function Observer.new<T>(config: {
	groups: { Types.Group<any> }?,
	priority: number?,
	updateRate: number?,
	precision: number?,
	enabled: boolean?,
	safety: boolean?,
}?): Types.Observer<T>
	local id = State.nextObserverId
	State.nextObserverId += 1

	local self: Types.InternalObserver<T> = setmetatable({
		id = id,
	}, Observer) :: any

	State.observerPriorityMap[id] = config and config.priority or 0
	State.observerUpdateRate[id] = config and config.updateRate or Config.Observer.updateRate
	State.observerPrecisionSq[id] = (config and config.precision or Config.Observer.precision) ^ 2

	State.observerEnteredCallbacks[id] = {}
	State.observerExitedCallbacks[id] = {}
	State.observerTransitionedCallbacks[id] = {}
	State.observerTrackingEntities[id] = {}
	State.observerIdToObserverObj[id] = self
	State.observerEnabled[id] = if config and config.enabled ~= nil then config.enabled else true
	State.observerSafety[id] = if config and config.safety ~= nil then config.safety else Config.Observer.safety
	State.observerStaticCount[id] = 0
	State.observerDynamicCount[id] = 0

	if config and config.groups then
		for _, group in config.groups do
			self:subscribe(group)
		end
	end

	return self
end

function Observer.subscribe(self: Types.InternalObserver<any>, group: Types.InternalGroup<any>): Types.Observer<any>
	local groupId = group.id
	if not State.groupToObservers[groupId] then
		State.groupToObservers[groupId] = {}
	end
	State.groupToObservers[groupId][self.id] = true

	for _, entity in group.entities do
		dirtyProfiles[entity] = true
		dirtyTopology[entity] = true
	end

	return self
end

function Observer.unsubscribe(self: Types.InternalObserver<any>, group: Types.InternalGroup<any>): Types.Observer<any>
	local groupId = group.id

	if State.groupToObservers[groupId] then
		State.groupToObservers[groupId][self.id] = nil
	end

	disconnectObserverFromGroup(self.id, group)

	return self
end

function Observer.observe(self: Types.InternalObserver<any>, callback: (any, Types.Zone) -> (() -> ())?): () -> ()
	local cleanups = {} :: { [Types.Entity]: () -> () }
	local activeIds = {} :: { [Types.Entity]: number }
	local nextId = 0

	local cleanupEnter = self:onEnter(function(entity, zone)
		entity = State.referenceToEntity[entity] or entity

		nextId += 1
		local observerId = nextId
		activeIds[entity] = observerId

		local cleanup = callback(entity, zone)

		if activeIds[entity] ~= observerId then
			if type(cleanup) == "function" then
				cleanup()
			end
			return
		end

		if type(cleanup) == "function" then
			cleanups[entity] = cleanup
		end
	end)

	local cleanupExit = self:onExit(function(entity, _)
		entity = State.referenceToEntity[entity] or entity

		activeIds[entity] = nil

		local cleanup = cleanups[entity]
		if cleanup then
			cleanups[entity] = nil
			cleanup()
		end
	end)

	return function()
		cleanupEnter()
		cleanupExit()

		table.clear(activeIds)

		for entity, cleanup in cleanups do
			cleanups[entity] = nil
			task.spawn(cleanup)
		end
	end
end

function Observer.onEnter(self: Types.InternalObserver<any>, callback: (any, Types.Zone) -> ()): () -> ()
	table.insert(State.observerEnteredCallbacks[self.id], callback)
	return function()
		local idx = table.find(State.observerEnteredCallbacks[self.id], callback)
		if idx then
			table.remove(State.observerEnteredCallbacks[self.id], idx)
		end
	end
end

function Observer.onExit(self: Types.InternalObserver<any>, callback: (any, Types.Zone) -> ()): () -> ()
	table.insert(State.observerExitedCallbacks[self.id], callback)
	return function()
		local idx = table.find(State.observerExitedCallbacks[self.id], callback)
		if idx then
			table.remove(State.observerExitedCallbacks[self.id], idx)
		end
	end
end

function Observer.observePlayer(
	self: Types.InternalObserver<any>,
	callback: (Player, Types.Zone) -> (() -> ())?
): () -> ()
	local cleanups = {} :: { [Types.Entity]: () -> () }
	local activeIds = {} :: { [Types.Entity]: number }
	local nextId = 0

	local cleanupEnter = self:onEnter(function(entity, zone)
		entity = State.referenceToEntity[entity] or entity
		local player = State.entityToReference[entity] or entity

		if not (typeof(player) == "Instance" and player:IsA("Player")) then
			return
		end

		nextId += 1
		local observerId = nextId
		activeIds[entity] = observerId

		local cleanup = callback(player, zone)

		if activeIds[entity] ~= observerId then
			if type(cleanup) == "function" then
				cleanup()
			end
			return
		end

		if type(cleanup) == "function" then
			cleanups[entity] = cleanup
		end
	end)

	local cleanupExit = self:onExit(function(entity, _)
		entity = State.referenceToEntity[entity] or entity

		if not activeIds[entity] then
			return
		end

		activeIds[entity] = nil

		local cleanup = cleanups[entity]
		if cleanup then
			cleanups[entity] = nil
			cleanup()
		end
	end)

	return function()
		cleanupEnter()
		cleanupExit()

		table.clear(activeIds)

		for entity, cleanup in cleanups do
			cleanups[entity] = nil
			task.spawn(cleanup)
		end
	end
end

function Observer.onPlayerEnter(self: Types.InternalObserver<any>, callback: (Player, Types.Zone) -> ()): () -> ()
	return self:onEnter(function(entity, zone)
		if typeof(entity) == "Instance" and entity:IsA("Player") then
			callback(entity, zone)
		end
	end)
end

function Observer.onPlayerExit(self: Types.InternalObserver<any>, callback: (Player, Types.Zone) -> ()): () -> ()
	return self:onExit(function(entity, zone)
		if typeof(entity) == "Instance" and entity:IsA("Player") then
			callback(entity, zone)
		end
	end)
end

function Observer.observeLocalPlayer(self: Types.InternalObserver<any>, callback: (Types.Zone) -> (() -> ())?): () -> ()
	assert(IS_CLIENT, "[QuickZone] Observer:observeLocalPlayer can only be called on the Client.")

	local cleanups = {} :: { [Types.Entity]: () -> () }
	local activeIds = {} :: { [Types.Entity]: number }
	local nextId = 0

	local cleanupEnter = self:onEnter(function(entity, zone)
		entity = State.referenceToEntity[entity] or entity
		local player = State.entityToReference[entity] or entity

		if player ~= Players.LocalPlayer then
			return
		end

		nextId += 1
		local observerId = nextId
		activeIds[entity] = observerId

		local cleanup = callback(zone)

		if activeIds[entity] ~= observerId then
			if type(cleanup) == "function" then
				cleanup()
			end
			return
		end

		if type(cleanup) == "function" then
			cleanups[entity] = cleanup
		end
	end)

	local cleanupExit = self:onExit(function(entity, _)
		entity = State.referenceToEntity[entity] or entity

		if not activeIds[entity] then
			return
		end

		activeIds[entity] = nil

		local cleanup = cleanups[entity]
		if cleanup then
			cleanups[entity] = nil
			cleanup()
		end
	end)

	return function()
		cleanupEnter()
		cleanupExit()

		table.clear(activeIds)

		for entity, cleanup in cleanups do
			cleanups[entity] = nil
			task.spawn(cleanup)
		end
	end
end

function Observer.onLocalPlayerEnter(self: Types.InternalObserver<any>, callback: (Types.Zone) -> ()): () -> ()
	assert(IS_CLIENT, "[QuickZone] Observer:onLocalPlayerEnter can only be called on the Client.")
	return self:onEnter(function(entity, zone)
		if entity == Players.LocalPlayer then
			callback(zone)
		end
	end)
end

function Observer.onLocalPlayerExit(self: Types.InternalObserver<any>, callback: (Types.Zone) -> ()): () -> ()
	assert(IS_CLIENT, "[QuickZone] Observer:onLocalPlayerExit can only be called on the Client.")
	return self:onExit(function(entity, zone)
		if entity == Players.LocalPlayer then
			callback(zone)
		end
	end)
end

function Observer.observeGroup(
	self: Types.InternalObserver<any>,
	callback: (Types.Group<any>, Types.Zone) -> (() -> ())?
): () -> ()
	local activeMembers = {} :: { [number]: { [Types.Entity]: boolean } }
	local cleanups = {} :: { [number]: () -> () }

	return self:observe(function(entity, zone)
		entity = State.referenceToEntity[entity] or entity

		local groups = State.entityToGroups[entity]
		if not groups then
			return
		end

		for groupId, _ in groups do
			local group = State.groups[groupId]
			if not group or not State.groupToObservers[groupId][self.id] then
				continue
			end

			if not activeMembers[groupId] then
				activeMembers[groupId] = {}
			end

			if next(activeMembers[groupId]) == nil then
				activeMembers[groupId][entity] = true
				local groupCleanup = callback(group, zone)
				if typeof(groupCleanup) == "function" then
					cleanups[groupId] = groupCleanup
				end
			else
				activeMembers[groupId][entity] = true
			end
		end

		return function()
			for groupId, members in activeMembers do
				if not members[entity] then
					continue
				end

				members[entity] = nil
				if next(members) ~= nil then
					continue
				end

				activeMembers[groupId] = nil
				local groupCleanup = cleanups[groupId]
				if groupCleanup then
					groupCleanup()
					cleanups[groupId] = nil
				end
			end
		end
	end)
end

function Observer.onGroupEnter(
	self: Types.InternalObserver<any>,
	callback: (Types.Group<any>, Types.Zone) -> ()
): () -> ()
	local activeMembers = {} :: { [number]: { [Types.Entity]: boolean } }

	return self:observe(function(entity, zone)
		entity = State.referenceToEntity[entity] or entity

		local groups = State.entityToGroups[entity]
		if not groups then
			return
		end

		for groupId, _ in groups do
			if not State.groupToObservers[groupId] or not State.groupToObservers[groupId][self.id] then
				continue
			end

			if not activeMembers[groupId] then
				activeMembers[groupId] = {}
			end

			local isFirst = next(activeMembers[groupId]) == nil
			activeMembers[groupId][entity] = true

			if isFirst then
				local group = State.groups[groupId]
				if group then
					callback(group, zone)
				end
			end
		end

		return function()
			for groupId, members in activeMembers do
				if not members[entity] then
					continue
				end

				members[entity] = nil
				if next(members) == nil then
					activeMembers[groupId] = nil
				end
			end
		end
	end)
end

function Observer.onGroupExit(
	self: Types.InternalObserver<any>,
	callback: (Types.Group<any>, Types.Zone) -> ()
): () -> ()
	local activeMembers = {} :: { [number]: { [Types.Entity]: boolean } }

	return self:observe(function(entity, zone)
		entity = State.referenceToEntity[entity] or entity

		local groups = State.entityToGroups[entity]
		if not groups then
			return
		end

		for groupId, _ in groups do
			if not State.groupToObservers[groupId] or not State.groupToObservers[groupId][self.id] then
				continue
			end

			if not activeMembers[groupId] then
				activeMembers[groupId] = {}
			end
			activeMembers[groupId][entity] = true
		end

		return function()
			for groupId, members in activeMembers do
				if not members[entity] then
					continue
				end

				members[entity] = nil
				if next(members) == nil then
					activeMembers[groupId] = nil
					local group = State.groups[groupId]
					if group then
						callback(group, zone)
					end
				end
			end
		end
	end)
end

function Observer.onTransition(self: Types.InternalObserver<any>, callback: (any, Types.Zone) -> ()): () -> ()
	table.insert(State.observerTransitionedCallbacks[self.id], callback)

	return function()
		local idx = table.find(State.observerTransitionedCallbacks[self.id], callback)
		if idx then
			table.remove(State.observerTransitionedCallbacks[self.id], idx)
		end
	end
end

function Observer.onPlayerTransition(self: Types.InternalObserver<any>, callback: (Player, Types.Zone) -> ()): () -> ()
	return self:onTransition(function(entity, newZone)
		local player = State.entityToReference[entity] or entity
		if typeof(player) == "Instance" and player:IsA("Player") then
			callback(player, newZone)
		end
	end)
end

function Observer.onLocalPlayerTransition(self: Types.InternalObserver<any>, callback: (Types.Zone) -> ()): () -> ()
	assert(IS_CLIENT, "[QuickZone] Observer:onLocalPlayerTransition can only be called on the Client.")

	return self:onTransition(function(entity, newZone)
		local player = State.entityToReference[entity] or entity
		if player == Players.LocalPlayer then
			callback(newZone)
		end
	end)
end

function Observer.setEnabled(self: Types.InternalObserver<any>, enabled: boolean): Types.Observer<any>
	local wasEnabled = self:isEnabled()

	if wasEnabled == enabled then
		return self
	end

	local id = self.id
	State.observerEnabled[id] = enabled
	State.logicVersion += 1

	if not enabled then
		for groupId, observersMap in State.groupToObservers do
			if not observersMap[id] then
				continue
			end

			local group = State.groups[groupId]
			if not group then
				continue
			end

			disconnectObserverFromGroup(id, group)
		end
	end

	updateAllEntitiesForObserver(self.id)

	return self
end

function Observer.setSafety(self: Types.InternalObserver<any>, enabled: boolean): Types.Observer<any>
	State.observerSafety[self.id] = enabled
	return self
end

function Observer.setPriority(self: Types.InternalObserver<any>, p: number): Types.Observer<any>
	State.observerPriorityMap[self.id] = p
	State.logicVersion += 1
	return self
end

function Observer.setUpdateRate(self: Types.InternalObserver<any>, hz: number): Types.Observer<any>
	assert(hz >= 0, "[QuickZone] updateRate must be non-negative")
	State.observerUpdateRate[self.id] = hz
	updateAllEntitiesForObserver(self.id)
	return self
end

function Observer.setPrecision(self: Types.InternalObserver<any>, n: number): Types.Observer<any>
	assert(n >= 0, "[QuickZone] precision must be non-negative")
	State.observerPrecisionSq[self.id] = n ^ 2
	updateAllEntitiesForObserver(self.id)
	return self
end

function Observer.isEnabled(self: Types.InternalObserver<any>): boolean
	return State.observerEnabled[self.id] ~= false
end

function Observer.isPointInside(self: Types.InternalObserver<any>, position: Vector3): boolean
	local px, py, pz = position.X, position.Y, position.Z
	local observerId = self.id

	local nodes = dynamicTree.nodes
	local index = 1
	local count = dynamicTree.count
	while index <= count do
		local node = nodes[index]
		local min, max = node.min, node.max

		if px < min.X or px > max.X or py < min.Y or py > max.Y or pz < min.Z or pz > max.Z then
			index = node.skipIndex
			continue
		end

		local hitId = node.id
		index += 1

		if hitId == 0 then
			continue
		end

		local observers = zoneAttachedObservers[hitId]
		if not observers or not table.find(observers, observerId) then
			continue
		end

		if isPointInShape(position, dynamicCFrames[hitId], dynamicHalfSizes[hitId], dynamicTypes[hitId]) then
			return true
		end
	end

	nodes = staticTree.nodes
	index = 1
	count = staticTree.count
	while index <= count do
		local node = nodes[index]
		local min, max = node.min, node.max

		if px < min.X or px > max.X or py < min.Y or py > max.Y or pz < min.Z or pz > max.Z then
			index = node.skipIndex
			continue
		end

		local hitId = node.id
		index += 1

		if hitId == 0 then
			continue
		end

		local observers = zoneAttachedObservers[hitId]
		if not observers or not table.find(observers, observerId) then
			continue
		end

		if isPointInShape(position, staticCFrames[hitId], staticHalfSizes[hitId], staticTypes[hitId]) then
			return true
		end
	end

	return false
end

function Observer.isSafe(self: Types.InternalObserver<any>): boolean
	return State.observerSafety[self.id]
end

function Observer.getId(self: Types.InternalObserver<any>): number
	return self.id
end

function Observer.getPriority(self: Types.InternalObserver<any>): number
	return State.observerPriorityMap[self.id]
end

function Observer.getUpdateRate(self: Types.InternalObserver<any>): number
	return State.observerUpdateRate[self.id]
end

function Observer.getPrecision(self: Types.InternalObserver<any>): number
	return math.sqrt(State.observerPrecisionSq[self.id])
end

function Observer.getEntitiesInside(self: Types.InternalObserver<any>): { any }
	local entities = State.observerTrackingEntities[self.id]
	if not entities then
		return {}
	end
	local results = {}
	for entity, _ in entities do
		local ref = State.entityToReference[entity] or entity
		table.insert(results, ref)
	end
	return results
end

function Observer.getPlayersInside(self: Types.InternalObserver<any>): { Player }
	local result = {}
	local entities = State.observerTrackingEntities[self.id]

	for entity in entities do
		local ref = State.entityToReference[entity] or entity
		if typeof(ref) == "Instance" and ref:IsA("Player") then
			if not table.find(result, ref) then
				table.insert(result, ref)
			end
		end
	end
	return result
end

function Observer.getZones(self: Types.InternalObserver<any>): { Types.Zone }
	local results = {}
	for zoneId, attachedList in State.zoneAttachedObservers do
		if not table.find(attachedList, self.id) then
			continue
		end

		local zone = State.zoneIdToZoneObj[zoneId]
		if zone then
			table.insert(results, zone)
		end
	end
	return results
end

function Observer.getGroups(self: Types.InternalObserver<any>): { Types.Group<any> }
	local result = {}

	for groupId, observersMap in State.groupToObservers do
		if not observersMap[self.id] then
			continue
		end

		local group = State.groups[groupId]
		if group then
			table.insert(result, group)
		end
	end

	return result
end

function Observer.getZoneOfEntity(self: Types.InternalObserver<any>, entity: any): Types.Zone?
	entity = State.referenceToEntity[entity] or entity

	local data = State.entityData[entity]
	if not data then
		return nil
	end

	local zoneId = data.activeObserverMemberships[self.id]
	if zoneId then
		return State.zoneIdToZoneObj[zoneId]
	end
	return nil
end

function Observer.getZoneOfPlayer(self: Types.InternalObserver<any>, player: Player): Types.Zone?
	return self:getZoneOfEntity(player)
end

function Observer.getEntitiesInZone(self: Types.InternalObserver<any>, zone: Types.Zone): { any }
	local results = {}

	for entity in self:iterEntitiesInZone(zone) do
		table.insert(results, entity)
	end

	return results
end

function Observer.getPlayersInZone(self: Types.InternalObserver<any>, zone: Types.Zone): { Player }
	local results = {}

	for player in self:iterPlayersInZone(zone) do
		table.insert(results, player)
	end

	return results
end

function Observer.iterZones(self: Types.InternalObserver<any>): () -> Types.Zone?
	local zoneId = nil
	local attachedList = nil
	local observerId = self.id

	return function(): Types.Zone?
		while true do
			zoneId, attachedList = next(zoneAttachedObservers, zoneId)

			if not zoneId then
				return nil
			end

			if not table.find(attachedList, observerId) then
				continue
			end

			local zone = State.zoneIdToZoneObj[zoneId]
			if zone then
				return zone
			end
		end
	end
end

function Observer.iterGroups(self: Types.InternalObserver<any>): () -> Types.Group<any>?
	local groupId = nil
	local observersMap = nil
	local observerId = self.id

	return function(): Types.Group<any>?
		while true do
			groupId, observersMap = next(State.groupToObservers, groupId)

			if not groupId then
				return nil
			end

			if not observersMap[observerId] then
				continue
			end

			local group = State.groups[groupId]
			if group then
				return group
			end
		end
	end
end

function Observer.iterEntitiesInside(self: Types.InternalObserver<any>): () -> (any?, Types.Zone?)
	local entities = State.observerTrackingEntities[self.id]
	local entity = nil
	local observerId = self.id

	return function()
		while true do
			entity = next(entities, entity)
			if not entity then
				return nil
			end

			local data = State.entityData[entity]
			if not data then
				continue
			end

			local zoneId = data.activeObserverMemberships[observerId]
			if not zoneId then
				continue
			end

			local ref = State.entityToReference[entity] or entity
			return ref, State.zoneIdToZoneObj[zoneId]
		end
	end
end

function Observer.iterPlayersInside(self: Types.InternalObserver<any>): () -> Player?
	local entities = State.observerTrackingEntities[self.id]
	local entity = nil
	local observerId = self.id

	return function()
		while true do
			entity = next(entities, entity)
			if not entity then
				return nil
			end

			local data = State.entityData[entity]
			if not data then
				continue
			end

			local zoneId = data.activeObserverMemberships[observerId]
			if not zoneId then
				continue
			end

			local ref = State.entityToReference[entity] or entity
			if typeof(ref) == "Instance" and ref:IsA("Player") then
				return ref, State.zoneIdToZoneObj[zoneId]
			end
		end
	end
end

function Observer.iterEntitiesInZone(self: Types.InternalObserver<any>, zone: Types.Zone): () -> Types.Entity?
	local entities = State.observerTrackingEntities[self.id]
	if not entities then
		return function()
			return nil
		end
	end

	local entity = nil
	local targetZoneId = zone:getId()
	local observerId = self.id

	return function(): Types.Entity?
		while true do
			entity = next(entities, entity)
			if not entity then
				return nil
			end

			local data = State.entityData[entity]

			if not data or data.activeObserverMemberships[observerId] ~= targetZoneId then
				continue
			end

			return State.entityToReference[entity] or entity
		end
	end
end

function Observer.iterPlayersInZone(self: Types.InternalObserver<any>, zone: Types.Zone): () -> Player?
	local entities = State.observerTrackingEntities[self.id]
	if not entities then
		return function()
			return nil
		end
	end

	local entity = nil
	local targetZoneId = zone:getId()
	local observerId = self.id

	return function(): Player?
		while true do
			entity = next(entities, entity)
			if not entity then
				return nil
			end

			local data = State.entityData[entity]

			if not data or data.activeObserverMemberships[observerId] ~= targetZoneId then
				continue
			end

			local ref = State.entityToReference[entity] or entity
			if typeof(ref) == "Instance" and ref:IsA("Player") then
				return ref
			end
		end
	end
end

function Observer.onDestroy(self: Types.InternalObserver<any>, callback: () -> ()): () -> ()
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

function Observer.destroy(self: Types.InternalObserver<any>): ()
	if self.onDestroyCallbacks then
		for _, callback in self.onDestroyCallbacks do
			task.spawn(callback)
		end
		table.clear(self.onDestroyCallbacks)
	end

	self:setEnabled(false)

	local id = self.id
	for _, observers in State.groupToObservers do
		observers[id] = nil
	end

	for _, attachedList in State.zoneAttachedObservers do
		local idx = table.find(attachedList, id)
		if idx then
			local lastIdx = #attachedList
			if idx ~= lastIdx then
				attachedList[idx] = attachedList[lastIdx]
			end
			attachedList[lastIdx] = nil
		end
	end

	State.observerPriorityMap[id] = nil
	State.observerEnteredCallbacks[id] = nil
	State.observerExitedCallbacks[id] = nil
	State.observerTransitionedCallbacks[id] = nil
	State.observerTrackingEntities[id] = nil
	State.observerIdToObserverObj[id] = nil
	State.observerEnabled[id] = nil
	State.observerSafety[id] = nil
	State.observerUpdateRate[id] = nil
	State.observerPrecisionSq[id] = nil
	State.observerStaticCount[id] = nil
	State.observerDynamicCount[id] = nil

	State.logicVersion += 1
	setmetatable(self :: any, nil)
end

return Observer
