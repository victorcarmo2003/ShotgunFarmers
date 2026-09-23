--!strict
export type function Build(leaf: type, extras: type): type
	if leaf:is("any") or leaf:is("unknown") or leaf:is("never") then
		return types.any
	end
	if extras:is("any") or extras:is("unknown") or extras:is("never") then
		return types.any
	end
	if not leaf:is("table") then
		error(`[SelfOf] leaf must be a table, got {leaf.tag}`)
	end
	if not extras:is("table") then
		error(`[SelfOf] extras must be a table, got {extras.tag}`)
	end

	local inner = types.newtable()
	local outer = types.newtable()

	for key, prop in extras:properties() do
		local t = prop.read or prop.write
		if t ~= nil then
			inner:setreadproperty(key, t)
			outer:setreadproperty(key, t)
		end
	end

	for key, prop in leaf:properties() do
		local t: type? = prop.read or prop.write
		if t ~= nil then
			local tt: type = t
			local isMethod = false
			local head: { type } = {}
			if tt:is("function") then
				local p = tt:parameters()
				head = if p.head then table.clone(p.head) else {}
				isMethod = #head > 0 and head[1] == leaf
			end

			if isMethod then
				local f = types.copy(tt)
				head[1] = inner
				f:setparameters(head, tt:parameters().tail)
				inner:setreadproperty(key, f)
				outer:setproperty(key, f)
			else
				inner:setproperty(key, tt)
				outer:setproperty(key, tt)
			end
		end
	end

	return outer
end

type _LeafSample = {
	Field: number,
	Method: (self: _LeafSample, n: number) -> (),
}

type _lspEvaluationAnchor = Build<_LeafSample, { Dependencies: {} }>

export type function RequireOf(props: type): type
	if props:is("any") or props:is("unknown") or props:is("never") then
		return types.never
	end
	if not props:is("table") then
		return types.never
	end
	local declared = props:readproperty(types.singleton("Require"))
	if declared == nil then
		return types.never
	end
	return declared
end

type _PropsSample = { Require: { "Sample" } }

type _lspAnchorRequireOf = RequireOf<_PropsSample>

return {}
