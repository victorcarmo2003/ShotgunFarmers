--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Throwables = require(ReplicatedStorage.shared.Weapon.Throwables)

export type State = {
	Position: Vector3,
	Velocity: Vector3,
	Age: number,
	Resting: boolean,
	Curve: number,
}

export type Contact = {
	Position: Vector3,
	Normal: Vector3,
	Instance: Instance,
}

const REST_SPEED = 3
const REST_NORMAL_Y = 0.6
const SURFACE_GAP = 0.02
const ROLL_IMPACT = 8
const ROLL_DRAG = 3
const MIN_CURVE_DISTANCE = 6

const ThrowSim = {}

function ThrowSim.new(origin: Vector3, velocity: Vector3, curve: number?): State
	return {
		Position = origin,
		Velocity = velocity,
		Age = 0,
		Resting = false,
		Curve = curve or 0,
	}
end

function ThrowSim.LaunchVelocity(definition: Throwables.Definition, direction: Vector3, power: number?): Vector3
	const scale = power or 1
	return direction.Unit * definition.Speed * scale + Vector3.yAxis * definition.Lift * scale
end

function ThrowSim.Power(launcher: boolean, mode: number): number
	if launcher then
		return 1
	end
	const index = math.clamp(math.round(mode), 1, #Throwables.THROW_POWERS)
	return Throwables.THROW_POWERS[index]
end

function ThrowSim.Aim(
	definition: Throwables.Definition,
	origin: Vector3,
	direction: Vector3,
	target: Vector3,
	power: number
): (Vector3, number)
	const angle = definition.CurveAngle
	if angle == 0 then
		return ThrowSim.LaunchVelocity(definition, direction, power), 0
	end

	local offset = target - origin
	const maxRange = if definition.MaxRange then definition.MaxRange * power else nil
	if maxRange and offset.Magnitude > maxRange then
		offset = offset.Unit * maxRange
	end

	const flat = Vector3.new(offset.X, 0, offset.Z)
	const distance = flat.Magnitude
	if distance < MIN_CURVE_DISTANCE then
		return ThrowSim.LaunchVelocity(definition, direction, power), 0
	end

	const duration = distance * angle / math.sin(angle) / definition.Speed
	const gravity = workspace.Gravity * definition.GravityScale
	const heading = CFrame.Angles(0, -angle, 0):VectorToWorldSpace(flat.Unit) * definition.Speed
	const drop = (definition.Drop or 0) * distance
	const rise = (offset.Y - drop) / duration + 0.5 * gravity * duration

	return Vector3.new(heading.X, rise, heading.Z), 2 * angle / duration
end

function ThrowSim.Params(): RaycastParams
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	return params
end

function ThrowSim.Ignore(owner: Player?, contact: boolean): { Instance }
	const ignore: { Instance } = {}

	const folder = workspace:FindFirstChild(Throwables.FOLDER_NAME)
	if folder then
		table.insert(ignore, folder)
	end

	const camera = workspace.CurrentCamera
	if camera then
		table.insert(ignore, camera)
	end

	for _, player in Players:GetPlayers() do
		const character = player.Character
		if character and (not contact or player == owner) then
			table.insert(ignore, character)
		end
	end

	return ignore
end

function ThrowSim.Step(definition: Throwables.Definition, state: State, params: RaycastParams): Contact?
	state.Age += Throwables.STEP
	if state.Resting then
		return nil
	end

	local velocity = state.Velocity
	if state.Curve ~= 0 then
		velocity = CFrame.Angles(0, state.Curve * Throwables.STEP, 0):VectorToWorldSpace(velocity)
	end
	velocity -= Vector3.yAxis * workspace.Gravity * definition.GravityScale * Throwables.STEP

	const displacement = velocity * Throwables.STEP
	if displacement.Magnitude <= 0 then
		state.Velocity = velocity
		return nil
	end

	const result = workspace:Spherecast(state.Position, Throwables.PROJECTILE_RADIUS, displacement, params)
	if not result then
		state.Position += displacement
		state.Velocity = velocity
		return nil
	end

	const normal = result.Normal
	state.Position += displacement.Unit * math.max(result.Distance - SURFACE_GAP, 0)

	if definition.Contact then
		state.Velocity = Vector3.zero
		state.Resting = true
		return {
			Position = state.Position,
			Normal = normal,
			Instance = result.Instance,
		}
	end

	const impact = velocity:Dot(normal)
	const normalPart = normal * impact
	const tangent = velocity - normalPart
	if -impact < ROLL_IMPACT then
		velocity = tangent * math.max(1 - ROLL_DRAG * Throwables.STEP, 0)
	else
		velocity = tangent * definition.Friction - normalPart * definition.Bounciness
	end

	if velocity.Magnitude < REST_SPEED and normal.Y > REST_NORMAL_Y then
		velocity = Vector3.zero
		state.Resting = true
	end

	state.Velocity = velocity
	return nil
end

return ThrowSim
