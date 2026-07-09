return function(base: { any }, Merge: { any }): { [string]: any }
	local merged = table.clone(base)
	for index, key in Merge do
		merged[index] = key
	end
	return merged
end
