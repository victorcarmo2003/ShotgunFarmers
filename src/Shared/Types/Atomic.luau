--!strict
type Sample = { Coins: number, Name: string }

export type function Of(value: type): type
	const getter = types.newfunction({ head = {} }, { head = { value } })
	const setter = types.newfunction({ head = { value } }, { head = { value } })
	return types.intersectionof(getter, setter)
end

export type function Table(t: type): type
	if not t:is("table") then
		error(`[Atomic] expected a table, got {t.tag}`)
	end

	const result = types.newtable()
	for key, prop in t:properties() do
		const value = prop.read or prop.write
		if value ~= nil then
			const getter = types.newfunction({ head = {} }, { head = { value } })
			const setter = types.newfunction({ head = { value } }, { head = { value } })
			result:setproperty(key, types.intersectionof(getter, setter))
		end
	end
	return result
end

type _anchorOf = Of<number>
type _anchorTable = Table<Sample>

return {}
