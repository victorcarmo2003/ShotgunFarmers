--!strict
type Example = {
	name: string,
	hp: number,
	weapon: string?,
}

export type function Partial(t: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[Partial] expected a table, got {t.tag}`)
	end
	local out = types.newtable()
	for key, prop in t:properties() do
		local value = prop.read or prop.write
		if value ~= nil then
			out:setproperty(key, types.optional(value))
		end
	end
	return out
end

export type function Required(t: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[Required] expected a table, got {t.tag}`)
	end
	local out = types.newtable()
	for key, prop in t:properties() do
		local value = prop.read or prop.write
		if value ~= nil then
			if value:is("union") then
				local remaining = {}
				for _, part in value:components() do
					if part.tag ~= "nil" then
						table.insert(remaining, part)
					end
				end
				if #remaining == 1 then
					value = remaining[1]
				elseif #remaining > 1 then
					value = types.unionof(table.unpack(remaining))
				end
			end
			out:setproperty(key, value)
		end
	end
	return out
end

export type function Readonly(t: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[Readonly] expected a table, got {t.tag}`)
	end
	local out = types.newtable()
	for key, prop in t:properties() do
		local value = prop.read or prop.write
		if value ~= nil then
			out:setreadproperty(key, value)
		end
	end
	return out
end

export type function Mutable(t: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[Mutable] expected a table, got {t.tag}`)
	end
	local out = types.newtable()
	for key, prop in t:properties() do
		local value = prop.read or prop.write
		if value ~= nil then
			out:setproperty(key, value)
		end
	end
	return out
end

type _anchorPartial = Partial<Example>
type _anchorRequired = Required<Example>
type _anchorReadonly = Readonly<Example>
type _anchorMutable = Mutable<Example>

export type function Assign(a: type, b: type): type
	if a:is("any") or a:is("unknown") or a:is("never") then
		return types.any
	end
	if b:is("any") or b:is("unknown") or b:is("never") then
		return types.any
	end
	if not a:is("table") or not b:is("table") then
		error(`[Assign] expected two tables, got {a.tag} e {b.tag}`)
	end
	local out = types.newtable()
	for key, prop in a:properties() do
		local value = prop.read or prop.write
		if value ~= nil then
			out:setproperty(key, value)
		end
	end
	for key, prop in b:properties() do
		local value = prop.read or prop.write
		if value ~= nil then
			out:setproperty(key, value)
		end
	end
	return out
end

export type function Merge(a: type, b: type): type
	if a:is("any") or a:is("unknown") or a:is("never") then
		return types.any
	end
	if b:is("any") or b:is("unknown") or b:is("never") then
		return types.any
	end
	if not a:is("table") or not b:is("table") then
		error(`[Merge] expected two tables, got {a.tag} e {b.tag}`)
	end

	local function fuse(x: type, y: type, budget: number): type
		if budget <= 0 or not x:is("table") or not y:is("table") then
			return y
		end
		local out = types.newtable()
		for key, prop in x:properties() do
			local value = prop.read or prop.write
			if value ~= nil then
				out:setproperty(key, value)
			end
		end
		for key, prop in y:properties() do
			local direita = prop.read or prop.write
			if direita ~= nil then
				local esquerda = nil
				for c, p in x:properties() do
					if c:value() == key:value() then
						esquerda = p.read or p.write
					end
				end
				if esquerda ~= nil and esquerda:is("table") and direita:is("table") then
					out:setproperty(key, fuse(esquerda, direita, budget - 1))
				else
					out:setproperty(key, direita)
				end
			end
		end
		return out
	end

	return fuse(a, b, 8)
end

export type function Record(keys: type, value: type): type
	if keys:is("any") or keys:is("unknown") or keys:is("never") then
		return types.any
	end
	local out = types.newtable()
	local function put(k: type)
		if not k:is("singleton") then
			error(`[Record] key must be a singleton, got {k.tag}`)
		end
		out:setproperty(k, value)
	end
	if keys:is("union") then
		for _, k in keys:components() do
			put(k)
		end
	else
		put(keys)
	end
	return out
end

export type function Rename(t: type, de: type, para: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[Rename] expected a table, got {t.tag}`)
	end
	if not de:is("singleton") or not para:is("singleton") then
		error("[Rename] from and to must be string singletons")
	end
	local target = de:value()
	local found = false
	local out = types.newtable()
	for key, prop in t:properties() do
		local value = prop.read or prop.write
		if value ~= nil then
			if key:value() == target then
				found = true
				out:setproperty(para, value)
			else
				out:setproperty(key, value)
			end
		end
	end
	if not found then
		error(`[Rename] field {tostring(target)} does not exist`)
	end
	return out
end

export type function DeepPartial(t: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[DeepPartial] expected a table, got {t.tag}`)
	end
	local function descend(x: type, budget: number): type
		if budget <= 0 or not x:is("table") then
			return x
		end
		local out = types.newtable()
		for key, prop in x:properties() do
			local value = prop.read or prop.write
			if value ~= nil then
				out:setproperty(key, types.optional(descend(value, budget - 1)))
			end
		end
		return out
	end
	return descend(t, 8)
end

export type function DeepReadonly(t: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[DeepReadonly] expected a table, got {t.tag}`)
	end
	local function descend(x: type, budget: number): type
		if budget <= 0 or not x:is("table") then
			return x
		end
		local out = types.newtable()
		for key, prop in x:properties() do
			local value = prop.read or prop.write
			if value ~= nil then
				out:setreadproperty(key, descend(value, budget - 1))
			end
		end
		return out
	end
	return descend(t, 8)
end

type Nested = { id: number, owner: { name: string, tag: string? } }

type _anchorAssign = Assign<Example, { hp: string }>
type _anchorMerge = Merge<Nested, { owner: { tag: string } }>
type _anchorRecord = Record<"a" | "b", number>
type _anchorRename = Rename<Example, "hp", "health">
type _anchorDeepPartial = DeepPartial<Nested>
type _anchorDeepReadonly = DeepReadonly<Nested>

return {}
