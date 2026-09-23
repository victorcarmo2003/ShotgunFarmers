--!strict
--!optimize 2

local Array = {}

function Array.swapRemove<T>(arr: { T }, idx: number): ()
	local last = #arr
	if idx ~= last then
		arr[idx] = arr[last]
	end
	arr[last] = nil
end

return table.freeze(Array)
