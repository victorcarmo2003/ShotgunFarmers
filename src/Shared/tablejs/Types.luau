--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Struct = require(ReplicatedStorage.shared.Types.Struct)
local Union = require(ReplicatedStorage.shared.Types.Union)

type Example = { name: string, hp: number }

export type Methods<T> = {
	keys: (self: any) -> Union.KeyList<T>,
	values: (self: any) -> Union.ValueList<T>,
	entries: (self: any) -> Union.Entries<T>,
	has: (self: any, key: keyof<T>) -> boolean,
	pick: (self: any) -> T,
	partial: (self: any) -> Struct.Partial<T>,
	freeze: (self: any) -> Struct.Readonly<T>,
	isFrozen: (self: any) -> boolean,
}

export type function Wrap(methods: type, target: type): type
	if methods:is("any") or methods:is("unknown") or methods:is("never") then
		return types.any
	end
	if target:is("any") or target:is("unknown") or target:is("never") then
		return types.any
	end
	if not methods:is("table") or not target:is("table") then
		error(`[Wrap] expected two tables, got {methods.tag} e {target.tag}`)
	end

	local out = types.newtable()
	for key, prop in target:properties() do
		local value = prop.read or prop.write
		if value ~= nil then
			out:setproperty(key, value)
		end
	end
	for key, prop in methods:properties() do
		local value = prop.read or prop.write
		if value ~= nil then
			out:setreadproperty(key, value)
		end
	end
	return out
end

export type Objeto<T> = Wrap<Methods<T>, T>

type _anchorWrap = Wrap<Methods<Example>, Example>

return {}
