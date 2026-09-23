--modux ignore file
--!strict
local RIG_WAIT_TIMEOUT = 5

local KEPT_PARTS: { [string]: boolean } = {
	Torso = true,
	["Right Arm"] = true,
	["Left Arm"] = true,
}

local ARM_SIZE = Vector3.new(1, 4, 1)

local function scalePart(rig: Model, part: BasePart, targetSize: Vector3)
	local originalSize = part.Size
	local factor =
		Vector3.new(targetSize.X / originalSize.X, targetSize.Y / originalSize.Y, targetSize.Z / originalSize.Z)

	part.Size = targetSize

	for _, child in part:GetChildren() do
		if child:IsA("Attachment") then
			local position = child.Position
			child.Position = Vector3.new(position.X * factor.X, position.Y * factor.Y, position.Z * factor.Z)
		elseif child:IsA("SpecialMesh") then
			local meshScale = child.Scale
			child.Scale = Vector3.new(meshScale.X * factor.X, meshScale.Y * factor.Y, meshScale.Z * factor.Z)
		end
	end

	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("Motor6D") or descendant:IsA("Weld") then
			local joint = descendant :: Motor6D
			if joint.Part0 == part then
				local position = joint.C0.Position
				joint.C0 = CFrame.new(position.X * factor.X, position.Y * factor.Y, position.Z * factor.Z)
					* joint.C0.Rotation
			end
			if joint.Part1 == part then
				local position = joint.C1.Position
				joint.C1 = CFrame.new(position.X * factor.X, position.Y * factor.Y, position.Z * factor.Z)
					* joint.C1.Rotation
			end
		end
	end
end

local function buildViewmodelRig(character: Model): (Model?, Animator?)
	local hasTorso = character:WaitForChild("Torso", RIG_WAIT_TIMEOUT)
	local hasRightArm = character:WaitForChild("Right Arm", RIG_WAIT_TIMEOUT)
	local hasLeftArm = character:WaitForChild("Left Arm", RIG_WAIT_TIMEOUT)
	if not hasTorso or not hasRightArm or not hasLeftArm then
		return nil, nil
	end

	character.Archivable = true

	local rig = character:Clone()
	if not rig then
		warn(
			"[ArmsController] character:Clone() retornou nil -- Archivable deve estar false em algum lugar do character/asset."
		)
		return nil, nil
	end
	rig.Name = "Viewmodel"

	for _, child in rig:GetChildren() do
		if not KEPT_PARTS[child.Name] then
			child:Destroy()
		end
	end

	local torso = rig:FindFirstChild("Torso") :: BasePart

	torso.Anchored = true
	torso.CanCollide = false
	torso.CanQuery = false
	torso.Transparency = 1

	for _, descendant in torso:GetChildren() do
		if descendant:IsA("Motor6D") and descendant.Part1 == nil then
			descendant:Destroy()
		end
	end

	for partName in KEPT_PARTS do
		if partName == "Torso" then
			continue
		end
		local part = rig:FindFirstChild(partName) :: BasePart?
		if part then
			part.CanCollide = false
			part.CanQuery = false
		end
	end

	rig.PrimaryPart = torso

	local rightArm = rig:FindFirstChild("Right Arm") :: BasePart?
	local leftArm = rig:FindFirstChild("Left Arm") :: BasePart?
	if rightArm then
		scalePart(rig, rightArm, ARM_SIZE)
	end
	if leftArm then
		scalePart(rig, leftArm, ARM_SIZE)
	end

	local animationController = Instance.new("AnimationController")
	animationController.Parent = rig
	local animator = Instance.new("Animator")
	animator.Parent = animationController

	return rig, animator
end

return buildViewmodelRig
