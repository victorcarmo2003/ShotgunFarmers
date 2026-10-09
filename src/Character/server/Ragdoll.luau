--!strict
const ROOT_NAME = "HumanoidRootPart"
const UPPER_ANGLE = 60
const TWIST_LOWER = -45
const TWIST_UPPER = 45

const Ragdoll = {}

function Ragdoll.Prepare(character: Model)
	const humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.BreakJointsOnDeath = false
	end
end

local function socket(motor: Motor6D)
	const part0 = motor.Part0
	const part1 = motor.Part1
	if not part0 or not part1 then
		return
	end

	const attachment0 = Instance.new("Attachment")
	attachment0.Name = "RagdollAttachment"
	attachment0.CFrame = motor.C0
	attachment0.Parent = part0

	const attachment1 = Instance.new("Attachment")
	attachment1.Name = "RagdollAttachment"
	attachment1.CFrame = motor.C1
	attachment1.Parent = part1

	const constraint = Instance.new("BallSocketConstraint")
	constraint.Name = "RagdollSocket"
	constraint.Attachment0 = attachment0
	constraint.Attachment1 = attachment1
	constraint.LimitsEnabled = true
	constraint.UpperAngle = UPPER_ANGLE
	constraint.TwistLimitsEnabled = true
	constraint.TwistLowerAngle = TWIST_LOWER
	constraint.TwistUpperAngle = TWIST_UPPER
	constraint.Parent = part1

	motor.Enabled = false
end

function Ragdoll.Apply(character: Model)
	if character:GetAttribute("Ragdolled") then
		return
	end
	character:SetAttribute("Ragdolled", true)

	const humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.BreakJointsOnDeath = false
		humanoid.AutoRotate = false
		humanoid.PlatformStand = true
	end

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") then
			const part0 = descendant.Part0
			const part1 = descendant.Part1
			const isRoot = (part0 and part0.Name == ROOT_NAME) or (part1 and part1.Name == ROOT_NAME)
			const inBody = part0 ~= nil
				and part1 ~= nil
				and part0:IsDescendantOf(character)
				and part1:IsDescendantOf(character)
				and part0.Parent == character
				and part1.Parent == character
			if inBody and not isRoot then
				socket(descendant)
			end
		elseif descendant:IsA("BasePart") and descendant.Parent == character then
			descendant.CanCollide = descendant.Name ~= ROOT_NAME
		end
	end
end

return Ragdoll
