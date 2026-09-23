--!strict

local RunService = game:GetService("RunService")

local Types = require(script.Types)
local Config = require(script.Config)
local Scheduler = require(script.Core.Scheduler)
local State = require(script.Core.State)
local Geometry = require(script.Utils.Geometry)
local LinearBVH = require(script.Utils.LinearBVH)

local queryPoint = LinearBVH.queryPoint
local isPointInShape = Geometry.isPointInShape

local zoneAttachedObservers = State.zoneAttachedObservers
local zoneIdToZoneObj = State.zoneIdToZoneObj
local entityData = State.entityData
local observerIdToObserverObj = State.observerIdToObserverObj
local groups = State.groups
local entityToGroups = State.entityToGroups
local entityToReference = State.entityToReference
local referenceToEntity = State.referenceToEntity

local staticCFrames = State.staticCFrames
local staticHalfSizes = State.staticHalfSizes
local staticTypes = State.staticTypes
local dynamicCFrames = State.dynamicCFrames
local dynamicHalfSizes = State.dynamicHalfSizes
local dynamicTypes = State.dynamicTypes
local dynamicTree = State.dynamicTree
local staticTree = State.staticTree

local debugConnection: RBXScriptConnection?
local debugFolder: Folder?
local debugVisuals = {} :: { [number]: BoxHandleAdornment }

export type QuickZone = Types.QuickZone
export type Zone = Types.Zone
export type Zones = Types.Zones
export type Observer<T> = Types.Observer<T>
export type Group<T> = Types.Group<T>
export type Entity = Types.Entity

local QuickZone = {
	Zone = require(script.Classes.Zone) :: Types.ZoneClass,
	Observer = require(script.Classes.Observer) :: Types.ObserverClass,
	Group = require(script.Classes.Group) :: Types.GroupClass,
}

function QuickZone:configure(config: { enabled: boolean?, autoSyncRate: number?, frameBudget: number? }): QuickZone
	if config.enabled ~= nil then
		self:setEnabled(config.enabled)
	end

	if config.autoSyncRate ~= nil then
		self:setAutoSyncRate(config.autoSyncRate)
	end

	if config.frameBudget ~= nil then
		self:setFrameBudget(config.frameBudget)
	end

	return self
end

function QuickZone:setEnabled(enabled: boolean): QuickZone
	Scheduler.setAutoUpdate(enabled)
	return self
end

function QuickZone:update(dt: number): QuickZone
	Scheduler.update(dt)
	return self
end

function QuickZone:setAutoSyncRate(hz: number): QuickZone
	Scheduler.setAutoSyncRate(hz)
	return self
end

function QuickZone:rebuild(): QuickZone
	Scheduler.rebuildTrees()
	return self
end

function QuickZone:setReference(reference: any, entity: Entity?): QuickZone
	if entity == nil then
		local oldEntity = referenceToEntity[reference]
		if oldEntity then
			entityToReference[oldEntity] = nil
		end
		referenceToEntity[reference] = nil
		return self
	end

	if reference == nil then
		local oldReference = entityToReference[entity]
		if oldReference then
			referenceToEntity[oldReference] = nil
		end
		entityToReference[entity] = nil
		return self
	end

	entityToReference[entity] = reference
	referenceToEntity[reference] = entity

	return self
end

function QuickZone:setFrameBudget(ms: number): QuickZone
	local s = ms / 1000
	Scheduler.setFrameBudget(s)
	return self
end

function QuickZone:removeEntity(entity: any): QuickZone
	entity = referenceToEntity[entity] or entity

	local groupIds = entityToGroups[entity]
	if not groupIds then
		return self
	end

	local idsToRemove = {}
	for groupId in groupIds do
		table.insert(idsToRemove, groupId)
	end

	for _, groupId in idsToRemove do
		local group = groups[groupId]
		if group then
			group:remove(entity)
		end
	end

	return self
end

function QuickZone:getEntityOfReference(reference: any): Types.Entity?
	local entity = referenceToEntity[reference]
	if entity then
		return entity
	end

	entity = reference
	if typeof(entity) == "Instance" then
		if
			entity:IsA("BasePart")
			or entity:IsA("Attachment")
			or entity:IsA("Bone")
			or entity:IsA("Camera")
			or entity:IsA("Model")
		then
			return entity
		end
	elseif typeof(entity) == "table" then
		if entity.Position or entity.CFrame or entity.WorldPosition or entity.GetPivot then
			return entity
		end
	end

	return nil
end

function QuickZone:getReferenceOfEntity(entity: any): any
	return entityToReference[entity] or entity
end

function QuickZone:getObservers(): { Types.Observer<any> }
	local result = {}
	for _, observer in observerIdToObserverObj do
		table.insert(result, observer)
	end
	return (result :: any) :: { Types.Observer<any> }
end

function QuickZone:getGroups(): { Types.Group }
	local result = {}
	for _, group in groups do
		table.insert(result, group)
	end
	return result
end

function QuickZone:getZones(): { Types.Zone }
	local result = {}
	for _, zone in zoneIdToZoneObj do
		table.insert(result, zone)
	end
	return result
end

function QuickZone:getEntities(): { any }
	local result = {}
	local count = 0

	for entity in entityData do
		count += 1
		result[count] = entityToReference[entity] or entity
	end

	return result
end

function QuickZone:getZonesAtPoint(position: Vector3): { Zone }
	local results = {}
	local count = 0

	queryPoint(dynamicTree, position, function(zoneId)
		if isPointInShape(position, dynamicCFrames[zoneId], dynamicHalfSizes[zoneId], dynamicTypes[zoneId]) then
			local zone = zoneIdToZoneObj[zoneId]
			if zone then
				count += 1
				results[count] = zone
			end
		end
	end)

	queryPoint(staticTree, position, function(zoneId)
		if isPointInShape(position, staticCFrames[zoneId], staticHalfSizes[zoneId], staticTypes[zoneId]) then
			local zone = zoneIdToZoneObj[zoneId]
			if zone then
				count += 1
				results[count] = zone
			end
		end
	end)

	return results
end

function QuickZone:getZonesOfEntity(entity: any): { Types.Zone }
	entity = referenceToEntity[entity] or entity
	local data = entityData[entity]
	if not data or not data.activeObserverMemberships then
		return {}
	end

	local results = {}
	local seenZones = {}

	for _, zoneId in data.activeObserverMemberships do
		if seenZones[zoneId] then
			continue
		end
		seenZones[zoneId] = true

		local zone = zoneIdToZoneObj[zoneId]
		if zone then
			table.insert(results, zone)
		end
	end

	return results
end

function QuickZone:getGroupsOfEntity(entity: any): { Types.Group }
	entity = referenceToEntity[entity] or entity
	local groupIds = entityToGroups[entity]
	if not groupIds then
		return {}
	end

	local results = {}
	local count = 0

	for groupId in groupIds do
		local group = groups[groupId]
		if group then
			count += 1
			results[count] = group
		end
	end

	return results
end

function QuickZone:iterGroups(): () -> Types.Group?
	local groupId = nil
	return function(): Types.Group?
		groupId = next(groups, groupId)
		return groupId and groups[groupId] or nil
	end
end

function QuickZone:iterZones(): () -> Types.Zone?
	local zoneId = nil

	return function(): Types.Zone?
		zoneId = next(zoneIdToZoneObj, zoneId)
		return zoneId and zoneIdToZoneObj[zoneId] or nil
	end
end

function QuickZone:iterEntities(): () -> any?
	local entity = nil

	return function(): any?
		entity = next(entityData, entity)
		if entity then
			return entityToReference[entity] or entity
		end
		return entity
	end
end

function QuickZone:iterObservers(): () -> Types.Observer<any>?
	local observerId = nil

	return function(): Types.Observer<any>?
		observerId = next(observerIdToObserverObj, observerId)
		return observerId and observerIdToObserverObj[observerId] or nil
	end
end

function QuickZone:iterGroupsOfEntity(entity: any): () -> Types.Group?
	entity = referenceToEntity[entity] or entity

	local groupIds = entityToGroups[entity]
	if not groupIds then
		return function()
			return nil
		end
	end

	local groupId = nil
	return function(): Types.Group?
		groupId = next(groupIds, groupId)
		return groupId and groups[groupId] or nil
	end
end

function QuickZone:iterZonesOfEntity(entity: any): () -> Types.Zone?
	entity = referenceToEntity[entity] or entity

	local data = entityData[entity]
	if not data or not data.activeObserverMemberships then
		return function()
			return nil
		end
	end

	local memberships = data.activeObserverMemberships
	local seenZones = {}
	local observerId = nil

	return function(): Types.Zone?
		while true do
			observerId = next(memberships, observerId)
			if not observerId then
				return nil
			end

			local zoneId = memberships[observerId]
			if seenZones[zoneId] then
				continue
			end

			seenZones[zoneId] = true
			local zone = zoneIdToZoneObj[zoneId]

			if zone then
				return zone
			end
		end
	end
end

function QuickZone:iterZonesAtPoint(point: Vector3): () -> Types.Zone?
	local dynamicNodes = dynamicTree.nodes
	local dynamicCount = dynamicTree.count or 0

	local staticNodes = staticTree.nodes
	local staticCount = staticTree.count or 0

	local px, py, pz = point.X, point.Y, point.Z

	local index = 1
	local checkingDynamic = true

	return function(): Types.Zone?
		if checkingDynamic then
			while index <= dynamicCount do
				local node = dynamicNodes[index]
				local min, max = node.min, node.max

				if px < min.X or px > max.X or py < min.Y or py > max.Y or pz < min.Z or pz > max.Z then
					index = node.skipIndex
					continue
				end

				index += 1
				local hitId = node.id

				if
					hitId > 0
					and isPointInShape(point, dynamicCFrames[hitId], dynamicHalfSizes[hitId], dynamicTypes[hitId])
				then
					return zoneIdToZoneObj[hitId]
				end
			end

			checkingDynamic = false
			index = 1
		end

		if not checkingDynamic then
			while index <= staticCount do
				local node = staticNodes[index]
				local min, max = node.min, node.max

				if px < min.X or px > max.X or py < min.Y or py > max.Y or pz < min.Z or pz > max.Z then
					index = node.skipIndex
					continue
				end

				index += 1
				local hitId = node.id

				if
					hitId > 0
					and isPointInShape(point, staticCFrames[hitId], staticHalfSizes[hitId], staticTypes[hitId])
				then
					return zoneIdToZoneObj[hitId]
				end
			end
		end

		return nil
	end
end

function QuickZone:visualize(enabled: boolean): QuickZone
	if debugConnection then
		debugConnection:Disconnect()
		debugConnection = nil
	end
	if debugFolder then
		debugFolder:Destroy()
		debugFolder = nil
	end
	table.clear(debugVisuals)

	if not enabled then
		return self
	end

	local newDebugFolder = Instance.new("Folder")
	newDebugFolder.Name = "QuickZone_Debug_Visuals"
	newDebugFolder.Parent = workspace
	debugFolder = newDebugFolder

	local function getOrCreateVisual(id: number): BoxHandleAdornment
		local box = debugVisuals[id]
		if not box then
			local newbox = Instance.new("BoxHandleAdornment")
			newbox.Name = "Zone_" .. id
			newbox.Adornee = workspace.Terrain
			newbox.Transparency = Config.Debug.transparency
			newbox.AlwaysOnTop = true
			newbox.ZIndex = 1
			newbox.Parent = debugFolder
			debugVisuals[id] = newbox
			box = newbox
		end
		return box
	end

	local loopEvent: RBXScriptSignal<number> = RunService:IsClient() and RunService.PreRender or RunService.Heartbeat

	debugConnection = loopEvent:Connect(function()
		if not debugFolder then
			return
		end

		for id, cframe in staticCFrames do
			local box = getOrCreateVisual(id)
			local halfSize = staticHalfSizes[id]

			local observers = zoneAttachedObservers[id]
			local isActive = observers and next(observers) ~= nil
			local color = isActive and Config.Debug.staticActive or Config.Debug.staticInactive

			box.Size = halfSize * 2
			box.CFrame = cframe
			box.Color3 = color
		end

		for id, cframe in dynamicCFrames do
			local box = getOrCreateVisual(id)
			local halfSize = dynamicHalfSizes[id]

			local observers = zoneAttachedObservers[id]
			local isActive = observers and next(observers) ~= nil
			local color = isActive and Config.Debug.dynamicActive or Config.Debug.dynamicInactive

			box.Size = halfSize * 2
			box.CFrame = cframe
			box.Color3 = color
		end

		for id, box in debugVisuals do
			if not staticCFrames[id] and not dynamicCFrames[id] then
				box:Destroy()
				debugVisuals[id] = nil
			end
		end
	end)

	return self
end

return QuickZone
