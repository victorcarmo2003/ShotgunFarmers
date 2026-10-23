--!strict
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local UserInputService = game:GetService("UserInputService")
local GetAnimations = require(ReplicatedStorage.shared.Character.GetAnimations)
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)
local SkinCatalog = require(ReplicatedStorage.shared.Shop.SkinCatalog)

const ROTATE_SPEED = 0.012
const PITCH_LIMIT = math.rad(80)
const SMOOTH = 14
const IDLE_DELAY = 3
const IDLE_SPEED = 0.35
const WHEEL_STEP = 0.1
const FIT_MARGIN = 1.6
const MIN_ZOOM = 0.5
const MAX_ZOOM = 2.4
const SCREEN_SHIFT = 0.45
const BASE_ROTATION = CFrame.Angles(0, -math.pi / 2, 0)
const SKIN_RESOLUTION = "2k"
const MUZZLE = "Muzzle"
const MIN_DIRECTION = 0.05
const FIREARM_FORWARD = Vector3.new(0, 0, -1)
const MELEE_UP = Vector3.new(0, 1, 0)

const UPRIGHT_FIX: { [string]: CFrame } = {
	Lemonade = CFrame.Angles(math.pi / 2, 0, 0),
}

export type Inspector = {
	Show: (gun: string, skin: SkinCatalog.Skin?) -> (),
	Hide: () -> (),
	Update: (dt: number, cameraCFrame: CFrame) -> (),
}

local function weaponAsset(name: string): Model?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const weapons = assets and assets:FindFirstChild("Weapons")
	const asset = weapons and weapons:FindFirstChild(name)
	if asset and asset:IsA("Model") then
		return asset
	end
	return nil
end

local function collectPoses(pose: Pose, poses: { [string]: CFrame })
	poses[pose.Name] = pose.CFrame
	for _, child in pose:GetSubPoses() do
		collectPoses(child :: Pose, poses)
	end
end

local function applyHoldPose(model: Model, gunData: GetGun.GunData)
	const set = GetAnimations.Viewmodel(gunData.AnimationSet) :: any
	const hold = if set then set.Hold else nil
	if typeof(hold) ~= "string" or hold == "" then
		return
	end

	const ok, sequence = pcall(function()
		return KeyframeSequenceProvider:GetKeyframeSequenceAsync(hold)
	end)
	if not ok or not sequence then
		return
	end

	const first = (sequence :: KeyframeSequence):GetKeyframes()[1]
	if not first then
		return
	end

	const poses: { [string]: CFrame } = {}
	for _, pose in (first :: Keyframe):GetPoses() do
		collectPoses(pose :: Pose, poses)
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Bone") and poses[descendant.Name] then
			descendant.Transform = poses[descendant.Name]
		elseif descendant:IsA("Motor6D") then
			const part0 = descendant.Part0
			const part1 = descendant.Part1
			const pose = if part1 then poses[part1.Name] else nil
			if part0 and part1 and pose then
				part1.CFrame = part0.CFrame * descendant.C0 * pose * descendant.C1:Inverse()
			end
		end
	end
end

local function meshBounds(model: Model, pivot: CFrame): (Vector3, Vector3)
	local minimum = Vector3.one * math.huge
	local maximum = -Vector3.one * math.huge
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("MeshPart") then
			const half = descendant.Size / 2
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						const corner = pivot:PointToObjectSpace((descendant.CFrame * CFrame.new(half * Vector3.new(x, y, z))).Position)
						minimum = Vector3.new(math.min(minimum.X, corner.X), math.min(minimum.Y, corner.Y), math.min(minimum.Z, corner.Z))
						maximum = Vector3.new(math.max(maximum.X, corner.X), math.max(maximum.Y, corner.Y), math.max(maximum.Z, corner.Z))
					end
				end
			end
		end
	end
	return minimum, maximum
end

local function rotationBetween(from: Vector3, to: Vector3): CFrame
	const source = from.Unit
	const target = to.Unit
	const axis = source:Cross(target)
	if axis.Magnitude < 1e-4 then
		if source:Dot(target) > 0 then
			return CFrame.identity
		end
		const side = if math.abs(source.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
		return CFrame.fromAxisAngle(source:Cross(side).Unit, math.pi)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(source:Dot(target), -1, 1)))
end

local function orientation(model: Model, gunData: GetGun.GunData, pivot: CFrame, center: Vector3): CFrame
	const upright = UPRIGHT_FIX[gunData.DisplayName]
	if upright then
		return upright
	end
	if gunData.PoseKind == "Throwable" then
		return CFrame.identity
	end

	const muzzle = model:FindFirstChild(MUZZLE, true)
	if not muzzle or not muzzle:IsA("Attachment") then
		return CFrame.identity
	end

	const direction = pivot:PointToObjectSpace(muzzle.WorldPosition) - center
	if direction.Magnitude < MIN_DIRECTION then
		return CFrame.identity
	end

	return rotationBetween(direction, if gunData.PoseKind == "Melee" then MELEE_UP else FIREARM_FORWARD)
end

local WeaponInspector = {}

function WeaponInspector.new(): Inspector
	local model: Model? = nil
	local center = Vector3.zero
	local fix = CFrame.identity
	local token = 0
	local baseDistance = 5
	local distance = 5
	local targetDistance = 5
	local yaw = 0
	local pitch = 0
	local targetYaw = 0
	local targetPitch = 0
	local lastInput = os.clock()
	local dragInput: InputObject? = nil
	local lastMouse: Vector2? = nil
	local pinchStart = 5
	const connections: { RBXScriptConnection } = {}

	local function clampDistance(value: number): number
		return math.clamp(value, baseDistance * MIN_ZOOM, baseDistance * MAX_ZOOM)
	end

	local function disconnect()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		dragInput = nil
		lastMouse = nil
	end

	local function connect()
		if #connections > 0 then
			return
		end

		table.insert(
			connections,
			UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
				if processed then
					return
				end
				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.MouseButton2
					or input.UserInputType == Enum.UserInputType.Touch
				then
					dragInput = input
					lastMouse = nil
					lastInput = os.clock()
				end
			end)
		)

		table.insert(
			connections,
			UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
				if input.UserInputType == Enum.UserInputType.MouseWheel then
					if not processed then
						targetDistance = clampDistance(targetDistance * (1 - input.Position.Z * WHEEL_STEP))
						lastInput = os.clock()
					end
					return
				end

				const active = dragInput
				if not active then
					return
				end
				const isMouse = input.UserInputType == Enum.UserInputType.MouseMovement
					and (active.UserInputType == Enum.UserInputType.MouseButton1 or active.UserInputType == Enum.UserInputType.MouseButton2)
				if not isMouse and input ~= active then
					return
				end

				local delta = Vector2.zero
				if isMouse then
					const position = Vector2.new(input.Position.X, input.Position.Y)
					if lastMouse then
						delta = position - lastMouse
					end
					lastMouse = position
				else
					delta = Vector2.new(input.Delta.X, input.Delta.Y)
				end

				targetYaw += delta.X * ROTATE_SPEED
				targetPitch = math.clamp(targetPitch + delta.Y * ROTATE_SPEED, -PITCH_LIMIT, PITCH_LIMIT)
				lastInput = os.clock()
			end)
		)

		table.insert(
			connections,
			UserInputService.InputEnded:Connect(function(input: InputObject)
				if input == dragInput then
					dragInput = nil
					lastMouse = nil
					lastInput = os.clock()
				end
			end)
		)

		table.insert(
			connections,
			UserInputService.TouchPinch:Connect(function(_positions, scale: number, _velocity, state: Enum.UserInputState, processed: boolean)
				if processed then
					return
				end
				if state == Enum.UserInputState.Begin then
					pinchStart = targetDistance
				elseif state == Enum.UserInputState.Change then
					targetDistance = clampDistance(pinchStart / math.max(scale, 0.05))
					lastInput = os.clock()
				end
			end)
		)
	end

	local function clear()
		if model then
			model:Destroy()
			model = nil
		end
	end

	local function show(gun: string, skin: SkinCatalog.Skin?)
		token += 1
		const mine = token

		const gunData = GetGun.ByName(gun)
		const asset = weaponAsset(gun)
		const camera = workspace.CurrentCamera
		if not gunData or not asset or not camera then
			clear()
			return
		end

		connect()

		task.spawn(function()
			const clone = asset:Clone()
			for _, descendant in clone:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.Anchored = true
					descendant.CanCollide = false
					descendant.CanQuery = false
					descendant.CanTouch = false
				end
			end

			if skin then
				SkinCatalog.Apply(clone, skin, SKIN_RESOLUTION)
			end
			if gunData.PoseKind == "Throwable" then
				applyHoldPose(clone, gunData)
			end

			pcall(function()
				ContentProvider:PreloadAsync({ clone })
			end)

			if mine ~= token then
				clone:Destroy()
				return
			end

			const pivot = clone:GetPivot()
			const minimum, maximum = meshBounds(clone, pivot)
			const size = maximum - minimum
			if size.Magnitude == math.huge or size.Magnitude ~= size.Magnitude then
				clone:Destroy()
				return
			end

			clear()
			center = (minimum + maximum) / 2
			fix = orientation(clone, gunData, pivot, center)
			const extent = size.Magnitude
			baseDistance = extent * 0.5 / math.tan(math.rad(camera.FieldOfView) / 2) * FIT_MARGIN * 0.75 + extent * 0.25
			distance = baseDistance
			targetDistance = baseDistance
			yaw = 0
			pitch = 0
			targetYaw = 0
			targetPitch = 0
			lastInput = os.clock()

			clone.Name = "WeaponInspector"
			model = clone
		end)
	end

	local function hide()
		token += 1
		clear()
		disconnect()
	end

	local function update(dt: number, cameraCFrame: CFrame)
		const current = model
		const camera = workspace.CurrentCamera
		if not current or not camera then
			return
		end
		const attached = current.Parent ~= nil

		if dragInput == nil and os.clock() - lastInput > IDLE_DELAY then
			targetYaw += dt * IDLE_SPEED
		end

		const alpha = 1 - math.exp(-dt * SMOOTH)
		yaw += (targetYaw - yaw) * alpha
		pitch += (targetPitch - pitch) * alpha
		distance += (targetDistance - distance) * alpha

		const viewport = camera.ViewportSize
		const halfWidth = math.tan(math.rad(camera.FieldOfView) / 2) * (viewport.X / math.max(viewport.Y, 1))
		const offsetX = distance * halfWidth * SCREEN_SHIFT

		current:PivotTo(
			cameraCFrame
				* CFrame.new(offsetX, 0, -distance)
				* CFrame.Angles(pitch, yaw, 0)
				* BASE_ROTATION
				* fix
				* CFrame.new(-center)
		)

		if not attached then
			current.Parent = camera
		end
	end

	return {
		Show = show,
		Hide = hide,
		Update = update,
	}
end

return WeaponInspector
