--!strict
const RIG_WAIT_TIMEOUT = 5

const KEPT_PARTS: { [string]: boolean } = {
	Torso = true,
	["Right Arm"] = true,
	["Left Arm"] = true,
}

const ARM_SIZE = Vector3.new(1, 4, 1)

local function scalePart(rig: Model, part: BasePart, targetSize: Vector3)
	const originalSize = part.Size
	const factor =
		Vector3.new(targetSize.X / originalSize.X, targetSize.Y / originalSize.Y, targetSize.Z / originalSize.Z)

	part.Size = targetSize

	for _, child in part:GetChildren() do
		if child:IsA("Attachment") then
			const position = child.Position
			child.Position = Vector3.new(position.X * factor.X, position.Y * factor.Y, position.Z * factor.Z)
		elseif child:IsA("SpecialMesh") then
			const meshScale = child.Scale
			child.Scale = Vector3.new(meshScale.X * factor.X, meshScale.Y * factor.Y, meshScale.Z * factor.Z)
		end
	end

	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("Motor6D") or descendant:IsA("Weld") then
			const joint = descendant :: Motor6D
			if joint.Part0 == part then
				const position = joint.C0.Position
				joint.C0 = CFrame.new(position.X * factor.X, position.Y * factor.Y, position.Z * factor.Z)
					* joint.C0.Rotation
			end
			if joint.Part1 == part then
				const position = joint.C1.Position
				joint.C1 = CFrame.new(position.X * factor.X, position.Y * factor.Y, position.Z * factor.Z)
					* joint.C1.Rotation
			end
		end
	end
end

local RigBuilder = {}

function RigBuilder.Build(character: Model): (Model?, Animator?)
	const hasTorso = character:WaitForChild("Torso", RIG_WAIT_TIMEOUT)
	const hasRightArm = character:WaitForChild("Right Arm", RIG_WAIT_TIMEOUT)
	const hasLeftArm = character:WaitForChild("Left Arm", RIG_WAIT_TIMEOUT)
	if not hasTorso or not hasRightArm or not hasLeftArm then
		warn("[RigBuilder] character sem Torso/Right Arm/Left Arm (rig nao e R6?); viewmodel nao sera criado")
		return nil, nil
	end

	character.Archivable = true

	const rig: Model? = character:Clone()
	if not rig then
		warn("[RigBuilder] character:Clone() devolveu nil -- ha algo com Archivable false dentro do character.")
		return nil, nil
	end
	rig.Name = "Viewmodel"

	for _, child in rig:GetChildren() do
		if not KEPT_PARTS[child.Name] then
			child:Destroy()
		end
	end

	const torso = rig:FindFirstChild("Torso") :: BasePart?
	if not torso then
		rig:Destroy()
		return nil, nil
	end

	torso.Anchored = true
	torso.CanCollide = false
	torso.CanQuery = false
	torso.Transparency = 1

	for _, child in torso:GetChildren() do
		if child:IsA("Motor6D") and child.Part1 == nil then
			child:Destroy()
		end
	end

	for partName in KEPT_PARTS do
		if partName == "Torso" then
			continue
		end
		const part = rig:FindFirstChild(partName) :: BasePart?
		if part then
			part.CanCollide = false
			part.CanQuery = false
		end
	end

	rig.PrimaryPart = torso

	const rightArm = rig:FindFirstChild("Right Arm") :: BasePart?
	const leftArm = rig:FindFirstChild("Left Arm") :: BasePart?
	if rightArm then
		scalePart(rig, rightArm, ARM_SIZE)
	end
	if leftArm then
		scalePart(rig, leftArm, ARM_SIZE)
	end

	const animationController = Instance.new("AnimationController")
	animationController.Parent = rig
	const animator = Instance.new("Animator")
	animator.Parent = animationController

	return rig, animator
end

return RigBuilder
