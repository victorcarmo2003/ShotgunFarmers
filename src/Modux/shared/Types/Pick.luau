type ManifestExample = {
	CurrencyService: { AddCash: () -> (), SubtractCash: () -> () },
	DataService: { FetchData: () -> (), ClearData: () -> () },
	PlayerService: { RespawnChar: () -> (), RemoveChar: () -> () },
}
export type function Table(list: type, id: type): type
	if not list:is("table") then
		error(`[Manifest] list must be the manifest table, got {list.tag}`)
	end

	if id:is("any") or id:is("unknown") or id:is("never") then
		return types.any
	end

	local function width(t: type): number?
		local target = t
		if target:is("table") then
			local ix = target:readindexer()
			if not ix then
				return nil
			end
			target = ix.result
		end
		if target:is("singleton") then
			return 1
		end
		if target:is("union") then
			local n = 0
			for _ in target:components() do
				n += 1
			end
			return n
		end
		return nil
	end

	if id:is("intersection") then
		local best, narrowest = nil, math.huge
		for _, part in id:components() do
			local w = width(part)
			if w and w < narrowest then
				narrowest, best = w, part
			end
		end
		if not best then
			error("[Manifest] intersection has no usable branch (no singleton, union, or array of them)")
		end
		id = best
	end

	local fromArray = false
	if id:is("table") then
		local indexer = id:readindexer()
		if not indexer then
			error("[Manifest] expected an array of keys, got a table with no indexer")
		end
		fromArray = true
		id = indexer.result
	end

	if id:is("string") then
		error(
			'[Manifest] WIDENED: as keys viraram `string`. Use `:: { "A" | "B" }` no literal, ou passe a union direto'
		)
	end

	if id:is("singleton") and not fromArray then
		local target = id:value()
		local prop = list:readproperty(id)
		if prop then
			return prop
		end
		local available = {}
		for key in list:properties() do
			table.insert(available, tostring(key:value()))
		end
		table.sort(available)
		error(`[Manifest] "{target}" does not exist. Available: {table.concat(available, ", ")}`)
	end

	local pedidos = {}
	if id:is("singleton") then
		pedidos[id:value()] = true
	elseif id:is("union") then
		for _, c in id:components() do
			if not c:is("singleton") then
				error(`[Manifest] union components must be singletons, got {c.tag}`)
			end
			pedidos[c:value()] = true
		end
	else
		error(`[Manifest] id must be a singleton, a union of singletons, or an array of them. Got {id.tag}`)
	end

	local resultado = types.newtable()
	for key, prop in list:properties() do
		local name = key:value()
		if type(name) == "string" and pedidos[name] then
			pedidos[name] = nil
			if prop.read then
				resultado:setreadproperty(key, prop.read)
			end
			if prop.write then
				resultado:setwriteproperty(key, prop.write)
			end
		end
	end

	local missing = {}
	for name in pedidos do
		table.insert(missing, name)
	end
	if #missing > 0 then
		table.sort(missing)
		local available = {}
		for key in list:properties() do
			table.insert(available, tostring(key:value()))
		end
		table.sort(available)
		error(
			`[Manifest] missing: {table.concat(missing, ", ")}. Available: {table.concat(available, ", ")}`
		)
	end

	return resultado
end

export type function Map(list: type, id: type): type
	if not list:is("table") then
		error(`[Manifest] list must be the manifest table, got {list.tag}`)
	end

	local pedidos = {}
	if id:is("singleton") then
		pedidos[id:value()] = true
	elseif id:is("union") then
		for _, c in id:components() do
			if not c:is("singleton") then
				error(`[Manifest] union components must be singletons, got {c.tag}`)
			end
			pedidos[c:value()] = true
		end
	elseif id:is("never") then
		return types.newtable()
	else
		error(`[Manifest] id must be a singleton or a union of singletons. Got {id.tag}`)
	end

	local resultado = types.newtable()
	for key, prop in list:properties() do
		local name = key:value()
		if type(name) == "string" and pedidos[name] then
			pedidos[name] = nil
			if prop.read then
				resultado:setreadproperty(key, prop.read)
			end
			if prop.write then
				resultado:setwriteproperty(key, prop.write)
			end
		end
	end

	local missing = {}
	for name in pedidos do
		table.insert(missing, name)
	end
	if #missing > 0 then
		table.sort(missing)
		local available = {}
		for key in list:properties() do
			table.insert(available, tostring(key:value()))
		end
		table.sort(available)
		error(
			`[Manifest] missing: {table.concat(missing, ", ")}. Available: {table.concat(available, ", ")}`
		)
	end
	return resultado
end

type CurrencyService = Table<ManifestExample, "CurrencyService">
type TwoServices = Table<ManifestExample, "PlayerService" | "DataService">

return {}
