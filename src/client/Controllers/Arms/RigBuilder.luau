--modux ignore file
--!strict
local RIG_WAIT_TIMEOUT = 5

local KEPT_PARTS: { [string]: boolean } = {
	Torso = true,
	["Right Arm"] = true,
	["Left Arm"] = true,
}
-- Tamanho FINAL absoluto do braço (não um fator multiplicativo) -- R6 puro é
-- Vector3.new(1, 2, 1), então isso já deixa o braço 2x mais comprido, sem alargar.
local ARM_SIZE = Vector3.new(1, 4, 1)

-- Redimensiona a part pra um Size ABSOLUTO e recalcula Attachments filhos e C0/C1 dos
-- Motor6D/Weld conectados a ela pelo FATOR REAL de mudança (targetSize/originalSize
-- por eixo) -- usar targetSize direto ali seria errado: um Attachment a 0.5 stud do
-- centro não deve pular pra "0.5 * 4", e sim escalar na mesma proporção que a part
-- mudou de tamanho. Foi exatamente esse bug (usar o Size final como se fosse fator)
-- que deixava o ombro/grip desalinhados e o braço "caindo".
local function scalePart(rig: Model, part: BasePart, targetSize: Vector3)
	local originalSize = part.Size
	local factor = Vector3.new(targetSize.X / originalSize.X, targetSize.Y / originalSize.Y, targetSize.Z / originalSize.Z)

	part.Size = targetSize

	for _, child in part:GetChildren() do
		if child:IsA("Attachment") then
			local position = child.Position
			child.Position = Vector3.new(position.X * factor.X, position.Y * factor.Y, position.Z * factor.Z)
		elseif child:IsA("SpecialMesh") then
			-- Cobre avatares com bundle/mesh customizado no braço (não é o R6 blocky
			-- puro) -- sem isso, o Size muda mas a malha visual fica no tamanho antigo.
			local meshScale = child.Scale
			child.Scale = Vector3.new(meshScale.X * factor.X, meshScale.Y * factor.Y, meshScale.Z * factor.Z)
		end
	end

	-- Motor6D/Weld não são filhos da part que eles conectam necessariamente (no R6,
	-- "Right Shoulder" é filho do Torso, não do braço) -- por isso varre o rig inteiro
	-- procurando por Part0/Part1 == part, em vez de só os children.
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("Motor6D") or descendant:IsA("Weld") then
			local joint = descendant :: Motor6D
			if joint.Part0 == part then
				local position = joint.C0.Position
				joint.C0 = CFrame.new(position.X * factor.X, position.Y * factor.Y, position.Z * factor.Z) * joint.C0.Rotation
			end
			if joint.Part1 == part then
				local position = joint.C1.Position
				joint.C1 = CFrame.new(position.X * factor.X, position.Y * factor.Y, position.Z * factor.Z) * joint.C1.Rotation
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

	-- Clone() retorna nil silenciosamente (sem erro) se Archivable estiver false --
	-- força true antes de clonar. Se o character costuma ficar Archivable=false por
	-- algum motivo real, isso é um sinal de que vale revisar o asset/rig usado como
	-- personagem no Studio.
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
	torso.Transparency = 1 -- só serve de root pros Motor6D, não deve aparecer

	-- Motor6D órfãos (Right Hip, Left Hip, Neck) sobram dentro do Torso mesmo depois
	-- do loop acima destruir Right Leg/Left Leg/Head -- esse loop só limpa os
	-- CHILDREN DIRETOS do rig (o Model raiz), não os Motor6D internos do Torso. Quando
	-- a part que eles apontavam (Part1) é destruída, a propriedade vira nil
	-- automaticamente -- filtrar por Part1 == nil pega exatamente esses órfãos sem
	-- remover o Right/Left Shoulder (que continuam apontando pros braços, ainda vivos).
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

	-- Esticado/alargado só nos braços -- Torso fica no tamanho original (não aparece,
	-- só serve de root pros Motor6D).
	local rightArm = rig:FindFirstChild("Right Arm") :: BasePart?
	local leftArm = rig:FindFirstChild("Left Arm") :: BasePart?
	if rightArm then
		scalePart(rig, rightArm, ARM_SIZE)
	end
	if leftArm then
		scalePart(rig, leftArm, ARM_SIZE)
	end

	-- AnimationController (não Humanoid) porque esse rig não anda/pula sozinho,
	-- só precisa tocar animações de braço.
	local animationController = Instance.new("AnimationController")
	animationController.Parent = rig
	local animator = Instance.new("Animator")
	animator.Parent = animationController

	return rig, animator
end

return buildViewmodelRig
