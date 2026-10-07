type Example = { name: string, hp: number, mana: number}

export type function Keys(t: type, k: type)
	if not t:is("table") then
		error(`expected a table`)
	end

	local occluded = {}
	local function register(ty: type)
		local value = ty:value()
		if type(value) ~= "string" then
			error(`singleton must be a string`)
		end
		occluded[value] = true
	end

	if k:is("union") then
		for _, ty in k:components() do
			if ty:is("singleton") then
				register(ty)
			end
		end
	elseif k:is("singleton") then
		register(k)
	else
		error(`k must be a union or a singleton`)
	end

	local result = types.copy(t)
	local toRemove = {}

	for index in result:properties() do
		local name = index:value()
		if type(name) == "string" and occluded[name] then
			table.insert(toRemove, index)
		end
	end

	for _, index in toRemove do
		result:setproperty(index, nil)
	end

	return result
end

type _E3_14 = Keys<Example, "mana">

return {}
