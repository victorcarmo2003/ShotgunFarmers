--!strict
type Example = { name: string, hp: number, weapon: string? }
type Color = "red" | "green" | "blue"

export type function Exclude(u: type, e: type): type
	if u:is("any") or u:is("unknown") or u:is("never") then
		return types.any
	end

	local outSet = {}
	local function mark(t: type)
		if t:is("singleton") then
			outSet[tostring(t:value())] = true
		else
			outSet[t.tag] = true
		end
	end
	if e:is("union") then
		for _, part in e:components() do
			mark(part)
		end
	else
		mark(e)
	end

	local function cut(t: type): boolean
		if t:is("singleton") then
			return outSet[tostring(t:value())] == true
		end
		return outSet[t.tag] == true
	end

	if not u:is("union") then
		return if cut(u) then types.never else u
	end
	local remaining = {}
	for _, part in u:components() do
		if not cut(part) then
			table.insert(remaining, part)
		end
	end
	if #remaining == 0 then
		return types.never
	end
	if #remaining == 1 then
		return remaining[1]
	end
	return types.unionof(table.unpack(remaining))
end

export type function Extract(u: type, e: type): type
	if u:is("any") or u:is("unknown") or u:is("never") then
		return types.any
	end

	local inSet = {}
	local function mark(t: type)
		if t:is("singleton") then
			inSet[tostring(t:value())] = true
		else
			inSet[t.tag] = true
		end
	end
	if e:is("union") then
		for _, part in e:components() do
			mark(part)
		end
	else
		mark(e)
	end

	local function keep(t: type): boolean
		if t:is("singleton") then
			return inSet[tostring(t:value())] == true
		end
		return inSet[t.tag] == true
	end

	if not u:is("union") then
		return if keep(u) then u else types.never
	end
	local remaining = {}
	for _, part in u:components() do
		if keep(part) then
			table.insert(remaining, part)
		end
	end
	if #remaining == 0 then
		return types.never
	end
	if #remaining == 1 then
		return remaining[1]
	end
	return types.unionof(table.unpack(remaining))
end

export type function NonNullable(t: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("union") then
		return t
	end
	local remaining = {}
	for _, part in t:components() do
		if part.tag ~= "nil" then
			table.insert(remaining, part)
		end
	end
	if #remaining == 0 then
		return types.never
	end
	if #remaining == 1 then
		return remaining[1]
	end
	return types.unionof(table.unpack(remaining))
end

export type function KeyList(t: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[KeyList] expected a table, got {t.tag}`)
	end
	local keys = {}
	for key in t:properties() do
		table.insert(keys, key)
	end
	local out = types.newtable()
	if #keys == 0 then
		out:setindexer(types.number, types.never)
	elseif #keys == 1 then
		out:setindexer(types.number, keys[1])
	else
		out:setindexer(types.number, types.unionof(table.unpack(keys)))
	end
	return out
end

export type function ValueList(t: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[ValueList] expected a table, got {t.tag}`)
	end
	local values = {}
	local seen = {}
	for _, prop in t:properties() do
		local value = prop.read or prop.write
		if value ~= nil then
			local signature = if value:is("singleton")
				then `singleton:{tostring(value:value())}`
				else value.tag
			if not seen[signature] then
				seen[signature] = true
				table.insert(values, value)
			end
		end
	end
	local out = types.newtable()
	if #values == 0 then
		out:setindexer(types.number, types.never)
	elseif #values == 1 then
		out:setindexer(types.number, values[1])
	else
		out:setindexer(types.number, types.unionof(table.unpack(values)))
	end
	return out
end

export type function Entries(t: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[Entries] expected a table, got {t.tag}`)
	end
	local pairsOut = {}
	for key, prop in t:properties() do
		local value = prop.read or prop.write
		if value ~= nil then
			local par = types.newtable()
			par:setreadproperty(types.singleton("key"), key)
			par:setreadproperty(types.singleton("value"), value)
			table.insert(pairsOut, par)
		end
	end
	local out = types.newtable()
	if #pairsOut == 0 then
		out:setindexer(types.number, types.never)
	elseif #pairsOut == 1 then
		out:setindexer(types.number, pairsOut[1])
	else
		out:setindexer(types.number, types.unionof(table.unpack(pairsOut)))
	end
	return out
end

type _anchorExclude = Exclude<Color, "green">
type _anchorExtract = Extract<Color, "green" | "blue">
type _anchorNonNullable = NonNullable<string?>
type _anchorKeyList = KeyList<Example>
type _anchorValueList = ValueList<Example>
type _anchorEntries = Entries<Example>

return {}
