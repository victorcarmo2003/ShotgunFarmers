--modux ignore file
--!strict

-- Toca as animações do viewmodel via KeyframeLoader (src/shared/Utils/KeyframeLoader),
-- não via Animator:LoadAnimation -- os 3 assets publicados (Idle/Aim/Shoot da Shotgun)
-- ficaram travados em moderação no servidor do Roblox (Length=0 mesmo publicados e
-- após esperar), e a API nativa que tocaria um KeyframeSequence sem publicar
-- (KeyframeSequenceProvider:RegisterKeyframeSequence) só funciona dentro do Studio,
-- não em produção. O KeyframeLoader contorna isso lendo o KeyframeSequence
-- diretamente e escrevendo em Motor6D/Bone.Transform manualmente, sem depender de
-- AssetId nenhum -- funciona igual em Studio e produção. Ver memória do projeto.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeLoader = require(ReplicatedStorage.Shared.Utils.KeyframeLoader)

local KEYFRAMES_FOLDER_PATH = { "Assets", "Keyframes" }

local ViewmodelKeyframes = {}

local function getKeyframesFolder(): Folder?
	local current: Instance = ReplicatedStorage
	for _, name in KEYFRAMES_FOLDER_PATH do
		local nextInstance = current:FindFirstChild(name)
		if not nextInstance then
			return nil
		end
		current = nextInstance
	end
	return current :: Folder
end

-- Junta Motor6D (ombro dos braços, filhos do Torso) com Bone (partes internas da arma
-- tipo gatilho/cano, importadas com armature dentro do Handle) numa única tabela --
-- AutoGetMotor6D só detecta UM tipo por chamada (para no primeiro Bone encontrado e
-- ignora todo Motor6D do resto do rig), então chamamos ele 2x forçando cada tipo e
-- mesclamos. Não colide: Motor6D indexa pelo nome da Part ("Right Arm"), Bone pelo
-- próprio nome do Bone ("Bone_001" etc).
local function buildJointTable(rig: Model): { [string]: Instance }
	local joints: { [string]: Instance } = {}
	for name, joint in KeyframeLoader.AutoGetMotor6D(rig, "Motor6D") do
		joints[name :: string] = joint :: Instance
	end
	for name, bone in KeyframeLoader.AutoGetMotor6D(rig, "Bone") do
		joints[name :: string] = bone :: Instance
	end
	return joints
end

export type KeyframeNames = {
	Idle: string,
	Aim: string,
	Shoot: string,
}

export type Player = KeyframeLoader.AT
export type Players = {
	Idle: Player?,
	Aim: Player?,
	Shoot: Player?,
}

-- Bug real na lib (init.luau, loop de CurrentPositionOfJoints): um joint só recebe
-- Transform se `CurrentlyAtDelta <= v.Time` pra algum frame -- numa animação de 1
-- keyframe só (pose estática, Time=0), isso vale só no instante exato Time=0; assim
-- que o relógio avança (0.016s no 1º frame de RunService já é o suficiente),
-- CurrentlyAtDelta > 0 SEMPRE, o joint é pulado (`continue`) pra sempre, e o Motor6D
-- fica preso na Transform anterior (identidade, se nunca foi setado). Confirmado via
-- debug: a Pose existe com Weight/CFrame corretos, mas nunca chega a ser aplicada.
-- Contorno sem mexer na lib de terceiros: duplica o único frame pra um Time futuro,
-- garantindo que sempre haja um frame "à frente" pra interpolar/sustentar.
local function ensureAtLeastTwoFrames(sequence: KeyframeSequence): { any }
	local frames = KeyframeLoader.KeyFrameSequanceToTable(sequence)
	if #frames == 1 then
		local duplicated = table.clone(frames[1])
		duplicated.Time = 1
		table.insert(frames, duplicated)
	end
	return frames
end

-- Monta os 3 players (Idle/Aim/Shoot) prontos pra tocar no rig+arma passados -- rig
-- precisa já ter a arma soldada dentro dele (senão os Bones do Handle não existem
-- ainda pra buildJointTable pegar). `keyframeNames` vem de GunData.Animations.Viewmodel
-- -- mesmos campos Idle/Aim/Shoot que antes guardavam rbxassetid://, agora guardam o
-- Name da KeyframeSequence dentro de ReplicatedStorage.Assets.Keyframes.
--
-- Os 3 compartilham o mesmo "Group" (clonado a cada chamada, parentado no rig, morre
-- junto com ele quando o rig é destruído) -- é o Group que faz o crossfade/blend real
-- entre eles; sem Group cada um escreveria em Motor6D.Transform de forma independente
-- e brigaria pelo mesmo valor a cada frame (pose "piscando").
function ViewmodelKeyframes.Build(rig: Model, keyframeNames: KeyframeNames): Players
	local folder = getKeyframesFolder()
	if not folder then
		warn("[ViewmodelKeyframes] ReplicatedStorage.Assets.Keyframes não encontrado.")
		return {}
	end

	-- EquipViewmodel pode rodar várias vezes no MESMO rig (troca de arma sem
	-- respawn) -- sem isso, o Group antigo (com animações ainda "vivas", cada uma
	-- com sua própria RunService connection) ficaria acumulado dentro do rig,
	-- brigando com o novo pelos mesmos Motor6D/Bone.
	local oldGroup = rig:FindFirstChild("KeyframeGroup")
	if oldGroup then
		oldGroup:Destroy()
	end

	local joints = buildJointTable(rig)
	local jointNames = {}
	for name in joints do
		table.insert(jointNames, name)
	end
	warn(`[ViewmodelKeyframes DEBUG] {#jointNames} joints coletados: {table.concat(jointNames, ", ")}`)

	local group = KeyframeLoader.CreateModuleGroup()
	group.Name = "KeyframeGroup"
	group.Parent = rig

	local players: Players = {}
	for key, keyframeName in keyframeNames :: { [string]: string } do
		if keyframeName == "" then
			continue
		end
		local sequence = folder:FindFirstChild(keyframeName)
		if sequence and sequence:IsA("KeyframeSequence") then
			local isStaticPose = key == "Idle" or key == "Aim"
			-- Pra Idle/Aim (poses estáticas, normalmente 1 keyframe só) passamos uma
			-- tabela pré-processada com o frame duplicado (ver ensureAtLeastTwoFrames)
			-- em vez do Instance direto -- contorna o bug da lib que nunca aplica
			-- Transform num joint cujo único frame já "passou" (Length=0 sempre conta
			-- como passado a partir do 2º tick de RunService).
			local animationSource: KeyframeSequence | { any } = if isStaticPose
				then ensureAtLeastTwoFrames(sequence :: KeyframeSequence)
				else sequence :: KeyframeSequence
			-- Cast :: any na chamada -- a assinatura de module.new declara Settings
			-- sem `?` (deveria ser opcional, o runtime já trata nil bem: "if Settings
			-- == nil then self.Settings = NotPassedSettings"), então o type-checker
			-- exige 4-5 argumentos mesmo passando só os 3 realmente necessários aqui.
			local player = (KeyframeLoader.new :: any)(joints, animationSource, group) :: Player
			if isStaticPose then
				-- KeyFrameSequanceToTable não seta Looped (só o construtor faz isso
				-- quando recebe o Instance direto) -- forçamos manualmente, já que
				-- pose estática sempre deve continuar "ligada".
				player.Looped = true
			end
			players[key] = player
			warn(
				`[ViewmodelKeyframes DEBUG] player "{key}" criado a partir de "{keyframeName}" -- Length={player.Length} Looped={player.Looped}`
			)

			-- Inspeciona direto a KeyframeSequence: existe uma Pose "Right Arm"/"Left Arm"
			-- gravada, e com que Weight? ConvertToTable.luau pula (continue) qualquer Pose
			-- com Weight == 0 -- se for esse o caso aqui, o Motor6D nunca recebe
			-- transformação nenhuma, mesmo com o player tocando normalmente.
			for _, keyframe in (sequence :: KeyframeSequence):GetKeyframes() do
				for _, jointName in { "Right Arm", "Left Arm" } do
					local pose = keyframe:FindFirstChild(jointName, true)
					if pose and pose:IsA("Pose") then
						warn(
							`[ViewmodelKeyframes DEBUG] [{key}] Keyframe "{keyframe.Name}" Pose "{jointName}": Weight={pose.Weight} CFrame={pose.CFrame}`
						)
					else
						warn(`[ViewmodelKeyframes DEBUG] [{key}] Keyframe "{keyframe.Name}" NÃO tem Pose "{jointName}".`)
					end
				end
			end
		else
			warn(
				`[ViewmodelKeyframes DEBUG] KeyframeSequence "{keyframeName}" NÃO encontrada em Assets.Keyframes (key="{key}").`
			)
		end
	end

	return players
end

return ViewmodelKeyframes
