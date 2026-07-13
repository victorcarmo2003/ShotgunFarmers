return function(Object:Model,Motor6DorBone:"Motor6D"|"Bone"):{}
	if Object == nil or typeof(Object)~="Instance" or not Object:IsA("Model") then warn("Not an model") return end
	local Motor6D = {}
	local Type:"Motor6D"|"Bone" = "Motor6D"
	for i,v in Object:GetDescendants() do
		if not v:IsA("Bone") then continue end
		Type = "Bone"
		break
	end
	
	if Motor6DorBone~=nil then
		Type = Motor6DorBone
	end
	if Type == "Motor6D" then
		for i,v in Object:GetDescendants() do
			if not v:IsA("BasePart") then continue end
			local joints = v:GetJoints()
			for ii,vv:Motor6D in joints do
			if not vv:IsA("Motor6D") then continue end
			if vv.Part1 == v then
				Motor6D[v.Name] = vv
				break
			end
		end
	end
	elseif Type == "Bone" then
		for i,v in Object:GetDescendants() do
			if not v:IsA("Bone") then continue end
			Motor6D[v.Name] = v
		end
	end
	return Motor6D,Type
end