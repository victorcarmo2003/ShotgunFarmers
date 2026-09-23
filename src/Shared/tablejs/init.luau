--!strict
local Types = require(script.Types)

export type Methods<T> = Types.Methods<T>
export type Objeto<T> = Types.Objeto<T>

const tablejs = {}

const isMethod = {
	keys = true,
	values = true,
	entries = true,
	has = true,
	pick = true,
	partial = true,
	freeze = true,
	isFrozen = true,
}

local function fields(self: any): { [any]: any }
	const out = {}
	for key, value in self :: { [any]: any } do
		if not isMethod[key] then
			out[key] = value
		end
	end
	return out
end

const methods = {}

function methods.keys(self: any): any
	const out = {}
	for key in fields(self) do
		table.insert(out, key)
	end
	return out
end

function methods.values(self: any): any
	const out = {}
	for _, value in fields(self) do
		table.insert(out, value)
	end
	return out
end

function methods.entries(self: any): any
	const out = {}
	for key, value in fields(self) do
		table.insert(out, { key = key, value = value })
	end
	return out
end

function methods.has(self: any, key: any): boolean
	return fields(self)[key] ~= nil
end

function methods.pick(self: any): any
	return fields(self)
end

function methods.partial(self: any): any
	return fields(self)
end

function methods.freeze(self: any): any
	return table.freeze(fields(self))
end

function methods.isFrozen(self: any): boolean
	return table.isfrozen(self)
end

function tablejs.New<T>(target: T): Types.Objeto<T>
	const object = {} :: { [any]: any }
	for key, value in (target :: { [any]: any }) do
		object[key] = value
	end
	for name, fn in (methods :: { [any]: any }) do
		object[name] = fn
	end
	return object :: any
end

return tablejs
