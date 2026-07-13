local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(StarterPlayer.StarterPlayerScripts.Client.Interface.Fusion)
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local GetGun = require(ReplicatedStorage.Shared.Utils.GetGun)
local buildViewmodelRig = require(StarterPlayer.StarterPlayerScripts.Client.Controllers.Arms.RigBuilder)
local WeaponAnimations = require(StarterPlayer.StarterPlayerScripts.Client.Controllers.Arms.WeaponAnimations)

local ArmsController = Modux.Controller("ArmsController"):Import("WeaponController"):Import("InputController")

-- Calculado a partir do CameraPart do ArmsReference (referência real do animador),
-- não estimado: offset = CameraPart.CFrame:Inverse() * Torso.CFrame, com CameraPart em
-- (-17, 3.5, -144.704) e Torso em (-17, 1.5, -145.5) no rig de referência parado.
local HIP_OFFSET = CFrame.new(0, -2, -0.796)
-- Igual ao HIP_OFFSET de propósito -- a pose "Aim" da animação já reposiciona a arma
-- pra centralizar na tela (rotação/posição do braço relativa ao Torso). Se o RIG
-- (Torso) TAMBÉM se deslocasse relativo à câmera aqui, os dois movimentos se somariam
-- e a mira subiria mais do que deveria -- só a pose dos braços deve mudar ao mirar,
-- não a posição do rig inteiro.
local AIM_OFFSET = HIP_OFFSET
local OFFSET_TRANSITION_RATE = 12

local ANIMATION_FADE_TIME = 0.15
local RENDER_BIND_NAME = "ArmsController_Follow"
local CHARACTER_ANIMATOR_WAIT_TIMEOUT = 5
-- Assets.Weapons.<Nome> pode ainda não ter chegado no client quando o character
-- acabou de spawnar (replicação de ReplicatedStorage não é instantânea, principalmente
-- com vários clients entrando ao mesmo tempo -- ver Team Test). FindFirstChild sozinho
-- desiste silenciosamente nesse caso (a arma nunca aparece); WaitForChild espera até
-- existir, só até esse timeout.
local WEAPON_ASSET_WAIT_TIMEOUT = 5

-- LockFirstPerson deixa o character real (e tudo soldado nele, incluindo o
-- WeaponVisual do EquipmentComponent) automaticamente invisível pro DONO via
-- LocalTransparencyModifier -- mas esse mecanismo só cobre BasePart, não SurfaceGui.
-- Sem isso, qualquer SurfaceGui dentro da arma (textura/decal feito via Gui em vez de
-- imagem normal) continua desenhada na tela, "flutuando" sobre uma part invisível.
local function hideSurfaceGuis(character: Model)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("SurfaceGui") then
			descendant.Enabled = false
		end
	end
end

-- Alterna entre a pose de hip-fire (Idle) e a de mira (Aim), com crossfade. Troca
-- tanto no viewmodel (só o dono vê) quanto no character real (replica pros outros).
ArmsController.SetAiming = function(self, aiming: boolean)
	if self.IsAiming == aiming then
		return
	end
	self.IsAiming = aiming
	-- Espelha self.IsAiming num Fusion Value -- o campo puro não é observável (nada
	-- reage quando muda); o Crosshair (Interface/GameComponents/Crosshair.luau) precisa
	-- de uma fonte reativa pra encolher/abrir as marcas de spread ao mirar.
	self.IsAimingValue:set(aiming)

	if aiming then
		if self.AimTrack then
			self.AimTrack:Play(ANIMATION_FADE_TIME)
		end
		if self.IdleTrack then
			self.IdleTrack:Stop(ANIMATION_FADE_TIME)
		end
		if self.CharacterAimTrack then
			self.CharacterAimTrack:Play(ANIMATION_FADE_TIME)
		end
		if self.CharacterIdleTrack then
			self.CharacterIdleTrack:Stop(ANIMATION_FADE_TIME)
		end
	else
		if self.IdleTrack then
			self.IdleTrack:Play(ANIMATION_FADE_TIME)
		end
		if self.AimTrack then
			self.AimTrack:Stop(ANIMATION_FADE_TIME)
		end
		if self.CharacterIdleTrack then
			self.CharacterIdleTrack:Play(ANIMATION_FADE_TIME)
		end
		if self.CharacterAimTrack then
			self.CharacterAimTrack:Stop(ANIMATION_FADE_TIME)
		end
	end
end

-- Troca a arma segurada pelo viewmodel (modelo físico + animações). O modelo depende
-- de um asset em ReplicatedStorage.Assets.Weapons.<DisplayName> com um Attachment
-- "Grip" (alinha com o RightGripAttachment do braço) e um Attachment "Muzzle" (de
-- onde o tiro visualmente sai). Sem esse asset, o viewmodel fica só com os braços.
ArmsController.EquipViewmodel = function(self, gunData: GetGun.GunData?)
	if self.WeaponModel then
		self.WeaponModel:Destroy()
		self.WeaponModel = nil
	end
	-- Stop(0) ANTES de Destroy() -- Destroy() sozinho não garante peso zerado no Animator
	-- (bug reconhecido pela própria Roblox: devforum.roblox.com/t/4525423, "animation
	-- tracks not being cleared from animator after destroyed or stopped"). Sem isso, ao
	-- trocar de arma enquanto mira (IsAiming = true), a pose de Aim antiga pode ficar
	-- "grudada" no rig por cima da animação nova, já que as duas têm peso total.
	if self.IdleTrack then
		self.IdleTrack:Stop(0)
		self.IdleTrack:Destroy()
		self.IdleTrack = nil
	end
	if self.AimTrack then
		self.AimTrack:Stop(0)
		self.AimTrack:Destroy()
		self.AimTrack = nil
	end
	if self.ShootTrack then
		self.ShootTrack:Stop(0)
		self.ShootTrack:Destroy()
		self.ShootTrack = nil
	end

	if not gunData or not self.Rig then
		return
	end

	local assetsFolder = ReplicatedStorage:WaitForChild("Assets", WEAPON_ASSET_WAIT_TIMEOUT)
	local weaponsFolder = assetsFolder and assetsFolder:WaitForChild("Weapons", WEAPON_ASSET_WAIT_TIMEOUT)
	local weaponAsset = weaponsFolder and weaponsFolder:WaitForChild(gunData.DisplayName, WEAPON_ASSET_WAIT_TIMEOUT)
	if weaponAsset then
		local weaponModel = weaponAsset:Clone() :: Model
		for _, descendant in weaponModel:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
				descendant.CanQuery = false
			end
		end

		weaponModel.Parent = self.Rig
		self.WeaponModel = weaponModel

		local rightArm = self.Rig:FindFirstChild("Right Arm") :: BasePart?
		local rightGrip = rightArm and (rightArm:FindFirstChild("RightGripAttachment") :: Attachment?)
		local weaponGrip = weaponModel:FindFirstChild("Grip", true) :: Attachment?
		local handle = weaponModel.PrimaryPart
		if not handle then
			handle = weaponModel:FindFirstChild("Handle", true)
		end

		if rightArm and rightGrip and weaponGrip and handle then
			weaponModel:PivotTo(rightGrip.WorldCFrame * weaponGrip.CFrame:Inverse())

			local handleMotor = handle:FindFirstChildOfClass("Motor6D")
			if handleMotor then
				-- Motor6D pré-criado no Handle no Studio -- preferido ao WeldConstraint
				-- porque permite animar recoil depois via C0, sem mexer em física.
				-- IMPORTANTE: Part1 é sempre a peça que o motor MOVE -- tem que ser o
				-- Handle (a arma segue o braço), nunca o braço (senão ele briga com o
				-- próprio Motor6D do ombro, que já é controlado pela animação, e o
				-- braço cai/desalinha). A fórmula alinha os dois Attachments "Grip":
				-- Part0.CFrame * C0 == Part1.CFrame * C1.
				handleMotor.Part0 = rightArm
				handleMotor.Part1 = handle
				handleMotor.C0 = rightGrip.CFrame
				handleMotor.C1 = weaponGrip.CFrame
			else
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = rightArm
				weld.Part1 = handle
				weld.Parent = weaponModel
			end

			-- Solda de segurança: qualquer OUTRA BasePart direta do weaponModel
			-- (Canos, Gatilho, Mira.001, Recargador, Handle) que não seja o "handle"
			-- (PrimaryPart) recebe um WeldConstraint direto pro handle já fixo no
			-- braço. Os Motor6D originais dessas partes (herdados do asset) apontam
			-- pra referências que não sobrevivem ao clone isolado do Model
			-- (Part0/Part1 quebrados/nil) -- sem NENHUMA fixação física válida, elas
			-- caem sob gravidade e o Roblox as destrói automaticamente ao saírem dos
			-- limites do mapa. Não afeta os Bones internos do Handle (continuam
			-- relativos a ele).
			for _, child in weaponModel:GetChildren() do
				if child:IsA("BasePart") and child ~= handle then
					local safetyWeld = Instance.new("WeldConstraint")
					safetyWeld.Part0 = handle
					safetyWeld.Part1 = child
					safetyWeld.Parent = child
				end
			end
		end
	end

	local anims = gunData.Animations.Viewmodel
	if self.Animator then
		local idleTrack = WeaponAnimations.LoadTrack(self.Animator, anims.Idle)
		local aimTrack = WeaponAnimations.LoadTrack(self.Animator, anims.Aim)
		local shootTrack = WeaponAnimations.LoadTrack(self.Animator, anims.Shoot)
		self.IdleTrack = idleTrack
		self.AimTrack = aimTrack
		self.ShootTrack = shootTrack
		-- Prioridade explícita pras 3 -- sem isso, Idle/Aim ficam com o Priority que
		-- veio do asset publicado (herdado do Animation Editor, pode ser inconsistente
		-- entre as 3 animações), e só o Shoot tinha prioridade garantida. Hierarquia:
		-- Shoot > Aim > Idle, pra tiro sempre sobrepor mira, que sempre sobrepõe idle.
		if idleTrack then
			idleTrack.Priority = Enum.AnimationPriority.Idle
		end
		if aimTrack then
			aimTrack.Priority = Enum.AnimationPriority.Action
		end
		if shootTrack then
			shootTrack.Looped = false
			shootTrack.Priority = Enum.AnimationPriority.Action2
		end
		if self.IsAiming then
			if aimTrack then
				aimTrack:Play(0)
			end
		elseif idleTrack then
			idleTrack:Play(0)
		end
	end
end

-- Equivalente a EquipViewmodel, mas pro Animator do character REAL (proporção normal,
-- sem o ARM_SIZE do viewmodel) -- animações tocadas aqui replicam automaticamente
-- pra todo mundo que vê esse character (é o próprio NetworkOwner tocando, o Roblox
-- cuida do resto sem precisar de nenhum pacote de rede). Priority Action garante que
-- sobrepõe a animação de movimento (Idle/Walk/Crouch) do AnimateController nos ossos em
-- comum -- só funciona bem se a animação gravada pro character NÃO tiver keyframes nas
-- pernas (senão compete com o Walk/Crouch por elas).
ArmsController.EquipCharacterPose = function(self, gunData: GetGun.GunData?)
	-- Mesmo motivo do EquipViewmodel: Stop(0) antes de Destroy() pra garantir que a pose
	-- antiga (ex: Aim, se trocou de arma mirando) solte o peso no CharacterAnimator.
	if self.CharacterIdleTrack then
		self.CharacterIdleTrack:Stop(0)
		self.CharacterIdleTrack:Destroy()
		self.CharacterIdleTrack = nil
	end
	if self.CharacterAimTrack then
		self.CharacterAimTrack:Stop(0)
		self.CharacterAimTrack:Destroy()
		self.CharacterAimTrack = nil
	end
	if self.CharacterShootTrack then
		self.CharacterShootTrack:Stop(0)
		self.CharacterShootTrack:Destroy()
		self.CharacterShootTrack = nil
	end

	if not gunData or not self.CharacterAnimator then
		return
	end

	local anims = gunData.Animations.Character

	local idleTrack = WeaponAnimations.LoadTrack(self.CharacterAnimator, anims.Idle)
	local aimTrack = WeaponAnimations.LoadTrack(self.CharacterAnimator, anims.Aim)
	local shootTrack = WeaponAnimations.LoadTrack(self.CharacterAnimator, anims.Shoot)
	-- Mesma hierarquia do viewmodel (Shoot > Aim > Idle), mas Idle continua Action (não
	-- Enum.AnimationPriority.Idle) aqui de propósito -- é isso que sobrepõe a animação de
	-- movimento (Idle/Walk/Crouch, Priority mais baixa) do AnimateController nos ossos
	-- em comum; se Idle desse braço ficasse em Priority.Idle, perderia pro Movement.
	if idleTrack then
		idleTrack.Priority = Enum.AnimationPriority.Action
	end
	if aimTrack then
		aimTrack.Priority = Enum.AnimationPriority.Action2
	end
	if shootTrack then
		shootTrack.Looped = false
		shootTrack.Priority = Enum.AnimationPriority.Action3
	end
	self.CharacterIdleTrack = idleTrack
	self.CharacterAimTrack = aimTrack
	self.CharacterShootTrack = shootTrack

	if self.IsAiming then
		if aimTrack then
			aimTrack:Play(0)
		end
	elseif idleTrack then
		idleTrack:Play(0)
	end
end

-- Toca a animação de disparo (não-looped) tanto no viewmodel quanto no character real
-- -- reaproveita os tracks já carregados por EquipViewmodel/EquipCharacterPose (em vez
-- de LoadAnimation a cada tiro) e força Stop+Play(0) pra sempre reiniciar do zero,
-- mesmo em fire rate alto (WatermeLMG etc.) onde o tiro anterior pode não ter acabado.
ArmsController.PlayShoot = function(self)
	if self.ShootTrack then
		self.ShootTrack:Stop(0)
		self.ShootTrack:Play(0)
	end
	if self.CharacterShootTrack then
		self.CharacterShootTrack:Stop(0)
		self.CharacterShootTrack:Play(0)
	end
end

-- Posição de onde o tiro deve visualmente sair. Cai pro braço direito enquanto
-- o asset da arma equipada (com Attachment "Muzzle") não existir.
ArmsController.GetMuzzlePosition = function(self): Vector3?
	if self.WeaponModel then
		local muzzle = self.WeaponModel:FindFirstChild("Muzzle", true) :: Attachment?
		if muzzle then
			return muzzle.WorldPosition
		end
	end

	local rightArm = self.Rig and (self.Rig:FindFirstChild("Right Arm") :: BasePart?)
	return rightArm and rightArm.Position
end

-- buildViewmodelRig usa WaitForChild (pode não estar tudo pronto assim que
-- CharacterAdded dispara) -- roda em task.spawn pra não travar OnStart/o evento,
-- e reconfirma que o character ainda é o atual antes de aplicar (evita aplicar um
-- rig obsoleto se o jogador respawnar de novo enquanto isso esperava).
ArmsController.RebuildRig = function(self, character: Model)
	if self.CharacterGuiConnection then
		self.CharacterGuiConnection:Disconnect()
		self.CharacterGuiConnection = nil
	end
	hideSurfaceGuis(character)
	-- WeaponVisual (e qualquer outra SurfaceGui) pode ser adicionada DEPOIS deste
	-- ponto (RefreshVisual do EquipmentComponent roda em task.spawn no servidor, ver
	-- EquipmentComponent.luau) -- esconde qualquer SurfaceGui nova que apareça daqui
	-- pra frente nesse character, sem precisar saber onde exatamente ela está.
	self.CharacterGuiConnection = character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("SurfaceGui") then
			descendant.Enabled = false
		end
	end)

	task.spawn(function()
		local rig, animator = buildViewmodelRig(character)

		if self.LocalPlayer.Character ~= character then
			if rig then
				rig:Destroy()
			end
			return
		end

		if self.Rig then
			self.Rig:Destroy()
			self.Rig = nil
		end
		self.WeaponModel = nil
		self.IdleTrack = nil
		self.AimTrack = nil
		self.ShootTrack = nil
		self.Animator = nil
		self.CharacterAnimator = nil
		self.CharacterIdleTrack = nil
		self.CharacterAimTrack = nil
		self.CharacterShootTrack = nil

		if not rig then
			return
		end

		rig.Parent = workspace.CurrentCamera
		self.Rig = rig
		self.Animator = animator
		self.CurrentOffset = HIP_OFFSET

		-- Animator do character REAL (não o do viewmodel) -- é nele que EquipCharacterPose
		-- toca a pose que replica pros outros players verem em 3ª pessoa.
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local characterAnimator = humanoid and humanoid:WaitForChild("Animator", CHARACTER_ANIMATOR_WAIT_TIMEOUT)
		self.CharacterAnimator = characterAnimator :: Animator?

		local gunData = Fusion.peek(self.WeaponController.GunData)
		self:EquipViewmodel(gunData)
		self:EquipCharacterPose(gunData)
	end)
end

ArmsController:OnInit(function(self)
	self.LocalPlayer = Players.LocalPlayer :: Player
	self.Scope = Fusion.scoped(Fusion)
	self.IsAimingValue = self.Scope:Value(false) :: Fusion.Value<boolean>
	self.Rig = nil :: Model?
	self.WeaponModel = nil :: Model?
	self.Animator = nil :: Animator?
	self.IdleTrack = nil :: AnimationTrack?
	self.AimTrack = nil :: AnimationTrack?
	self.ShootTrack = nil :: AnimationTrack?
	self.CharacterAnimator = nil :: Animator?
	self.CharacterIdleTrack = nil :: AnimationTrack?
	self.CharacterAimTrack = nil :: AnimationTrack?
	self.CharacterShootTrack = nil :: AnimationTrack?
	self.CharacterGuiConnection = nil :: RBXScriptConnection?
	self.IsAiming = false :: boolean
	self.CurrentOffset = HIP_OFFSET :: CFrame

	self.Scope:Observer(self.WeaponController.GunData):onChange(function()
		local gunData = Fusion.peek(self.WeaponController.GunData)
		self:EquipViewmodel(gunData)
		self:EquipCharacterPose(gunData)
	end)
end)

ArmsController:OnStart(function(self)
	if self.LocalPlayer.Character then
		self:RebuildRig(self.LocalPlayer.Character)
	end

	self:Cleanup(self.LocalPlayer.CharacterAdded:Connect(function(character: Model)
		self:RebuildRig(character)
	end))

	local aimHandler = self.InputController:BindAction("Aim", Enum.UserInputType.MouseButton2)
	aimHandler.OnPress(function()
		self:SetAiming(true)
	end)
	aimHandler.OnRelease(function()
		self:SetAiming(false)
	end)

	RunService:BindToRenderStep(RENDER_BIND_NAME, Enum.RenderPriority.Camera.Value + 2, function(deltaTime: number)
		local camera = workspace.CurrentCamera
		if not camera or not self.Rig then
			return
		end
		local targetOffset = if self.IsAiming then AIM_OFFSET else HIP_OFFSET
		local alpha = 1 - math.exp(-OFFSET_TRANSITION_RATE * deltaTime)
		self.CurrentOffset = self.CurrentOffset:Lerp(targetOffset, alpha)
		self.Rig:PivotTo(camera.CFrame * self.CurrentOffset)
	end)

	self:Cleanup(function()
		RunService:UnbindFromRenderStep(RENDER_BIND_NAME)
	end)
	self:Cleanup(function()
		if self.CharacterGuiConnection then
			self.CharacterGuiConnection:Disconnect()
		end
	end)
end)

return ArmsController
