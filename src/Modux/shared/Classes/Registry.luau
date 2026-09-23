--!strict
export type Entry = {
	ID: string,
	Class: any,
	Dependency: { string },
	Priority: number,
}

export type Store = { Entry }

export type Template = {
	ID: string,
	Tag: string,
	Class: any,
	Dependency: { string },
	Priority: number,
}

export type Templates = { [string]: Template }

const Registry = {}

function Registry.normalizeRequire(value: any): { string }
	if value == nil then
		return {}
	end
	if type(value) == "string" then
		return { value }
	end
	if type(value) == "table" then
		return value
	end
	error(`[Modux] Require must be a string or an array of strings, got {type(value)}`)
end

function Registry.register(kind: string, Base: any, store: Store, id: string, props: any): any
	for _, entry in store do
		if entry.ID == id then
			error(`[Modux - {kind}] Duplicated ID: {id}`)
		end
	end

	const p = (props or {}) :: { Require: any, Priority: number? }
	const instance = Base.New()

	table.insert(store, {
		ID = id,
		Class = instance :: any,
		Dependency = Registry.normalizeRequire(p.Require),
		Priority = p.Priority or 1,
	})

	return instance
end

function Registry.template(kind: string, Base: any, templates: Templates, id: string, props: any): any
	if templates[id] ~= nil then
		error(`[Modux - {kind}] Duplicated ID: {id}`)
	end

	const p = (props or {}) :: { Require: any, Priority: number?, Tag: string? }
	const class = Base.New()

	templates[id] = {
		ID = id,
		Tag = p.Tag or id,
		Class = class :: any,
		Dependency = Registry.normalizeRequire(p.Require),
		Priority = p.Priority or 1,
	}

	return class
end

return Registry
