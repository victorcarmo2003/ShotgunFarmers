--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)

export type Cast = {
	Result: RaycastResult?,
	EndPos: Vector3,
	Travel: number,
	Control: Vector3,
}

export type Sweep = {
	Closest: Vector3,
	Distance: number,
}

const DEFAULT_SPEED = 1000
const DEFAULT_DROP = 0.05
const SEGMENT_SECONDS = 0.04
const MAX_SEGMENTS = 16

const Ballistics = {}

function Ballistics.Speed(gunData: GetGun.GunData): number
	return gunData.BulletSpeed or DEFAULT_SPEED
end

function Ballistics.Drop(gunData: GetGun.GunData): number
	return gunData.BulletDrop or DEFAULT_DROP
end

function Ballistics.Travel(gunData: GetGun.GunData, distance: number): number
	return distance / Ballistics.Speed(gunData)
end

function Ballistics.Gravity(gunData: GetGun.GunData): number
	return workspace.Gravity * Ballistics.Drop(gunData)
end

function Ballistics.Control(origin: Vector3, direction: Vector3, speed: number, time: number): Vector3
	return origin + direction * speed * time * 0.5
end

function Ballistics.Bezier(start: Vector3, control: Vector3, finish: Vector3, alpha: number): Vector3
	const inverse = 1 - alpha
	return start * (inverse * inverse) + control * (2 * inverse * alpha) + finish * (alpha * alpha)
end

local function closestOnSegment(from: Vector3, to: Vector3, point: Vector3): Vector3
	const segment = to - from
	const length = segment:Dot(segment)
	if length <= 0 then
		return from
	end
	return from + segment * math.clamp((point - from):Dot(segment) / length, 0, 1)
end

function Ballistics.Sweep(
	gunData: GetGun.GunData,
	origin: Vector3,
	direction: Vector3,
	range: number,
	params: RaycastParams,
	target: Vector3
): Sweep
	const speed = Ballistics.Speed(gunData)
	const gravity = Ballistics.Gravity(gunData)
	const unit = direction.Unit
	const duration = range / speed
	const segments = math.clamp(math.ceil(duration / SEGMENT_SECONDS), 1, MAX_SEGMENTS)
	const step = duration / segments

	local previous = origin
	local travelled = 0
	local best = origin
	local bestGap = math.huge
	local bestDistance = 0
	for index = 1, segments do
		local point = Ballistics.Point(origin, unit, speed, gravity, step * index)
		const result = workspace:Raycast(previous, point - previous, params)
		if result then
			point = result.Position
		end

		const closest = closestOnSegment(previous, point, target)
		const gap = (closest - target).Magnitude
		if gap < bestGap then
			bestGap = gap
			best = closest
			bestDistance = travelled + (closest - previous).Magnitude
		end

		if result then
			break
		end
		travelled += (point - previous).Magnitude
		previous = point
	end

	return { Closest = best, Distance = bestDistance }
end

function Ballistics.Point(origin: Vector3, direction: Vector3, speed: number, gravity: number, time: number): Vector3
	return origin + direction * speed * time - Vector3.yAxis * 0.5 * gravity * time * time
end

function Ballistics.Cast(gunData: GetGun.GunData, origin: Vector3, direction: Vector3, params: RaycastParams): Cast
	const speed = Ballistics.Speed(gunData)
	const gravity = Ballistics.Gravity(gunData)
	const unit = direction.Unit
	const duration = gunData.Range / speed
	const segments = math.clamp(math.ceil(duration / SEGMENT_SECONDS), 1, MAX_SEGMENTS)
	const step = duration / segments

	local previous = origin
	local travelled = 0
	for index = 1, segments do
		const point = Ballistics.Point(origin, unit, speed, gravity, step * index)
		const offset = point - previous
		const result = workspace:Raycast(previous, offset, params)
		if result then
			travelled += (result.Position - previous).Magnitude
			const travel = travelled / speed
			return {
				Result = result,
				EndPos = result.Position,
				Travel = travel,
				Control = Ballistics.Control(origin, unit, speed, travel),
			}
		end
		travelled += offset.Magnitude
		previous = point
	end

	return { Result = nil, EndPos = previous, Travel = duration, Control = Ballistics.Control(origin, unit, speed, duration) }
end

return Ballistics
