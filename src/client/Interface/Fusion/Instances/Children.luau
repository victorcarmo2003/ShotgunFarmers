--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil

local Package = script.Parent.Parent
local Types = require(Package.Types)
local External = require(Package.External)
local Observer = require(Package.Graph.Observer)
local peek = require(Package.State.peek)
local castToState = require(Package.State.castToState)
local doCleanup = require(Package.Memory.doCleanup)

type Set<T> = { [T]: unknown }

local EXPERIMENTAL_AUTO_NAMING = false

return {
	type = "SpecialKey",
	kind = "Children",
	stage = "descendants",
	apply = function(self: Types.SpecialKey, scope: Types.Scope<unknown>, value: unknown, applyTo: Instance)
		local newParented: Set<Instance> = {}
		local oldParented: Set<Instance> = {}

		local newScopes: { [Types.StateObject<unknown>]: Types.Scope<unknown> } = {}
		local oldScopes: { [Types.StateObject<unknown>]: Types.Scope<unknown> } = {}

		local function updateChildren()
			oldParented, newParented = newParented, oldParented
			oldScopes, newScopes = newScopes, oldScopes

			local function processChild(child: unknown, autoName: string?)
				local childType = typeof(child)

				if childType == "Instance" then
					local child = child :: Instance

					newParented[child] = true
					if oldParented[child] == nil then
						child.Parent = applyTo
					else
						oldParented[child] = nil
					end

					if EXPERIMENTAL_AUTO_NAMING and autoName ~= nil then
						child.Name = autoName
					end
				elseif castToState(child) then
					local child = child :: Types.StateObject<unknown>

					local value = peek(child)

					if value ~= nil then
						processChild(value, autoName)
					end

					local childScope = oldScopes[child]
					if childScope == nil then
						childScope = {}
						Observer(childScope, child):onChange(updateChildren)
					else
						oldScopes[child] = nil
					end

					newScopes[child] = childScope
				elseif childType == "table" then
					local child = child :: { [unknown]: unknown }

					for key, subChild in pairs(child) do
						local keyType = typeof(key)
						local subAutoName: string? = nil

						if keyType == "string" then
							local key = key :: string
							subAutoName = key
						elseif keyType == "number" and autoName ~= nil then
							local key = key :: number
							subAutoName = autoName .. "_" .. key
						end

						processChild(subChild, subAutoName)
					end
				else
					External.logWarn("unrecognisedChildType", childType)
				end
			end

			if value ~= nil then
				processChild(value)
			end

			for oldInstance in pairs(oldParented) do
				oldInstance.Parent = nil
			end
			table.clear(oldParented)

			for oldState, childScope in pairs(oldScopes) do
				doCleanup(childScope)
			end
			table.clear(oldScopes)
		end

		table.insert(scope, function()
			value = nil
			updateChildren()
		end)

		updateChildren()
	end,
} :: Types.SpecialKey
