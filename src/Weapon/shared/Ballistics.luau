--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetGun = require(ReplicatedStorage.shared.Weapon.GetGun)

export type Cast = {
	Result: RaycastResult?,
	EndPos: Vector3,
	Travel: number,
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

function Ballistics.Point(origin: Vector3, direction: Vector3, speed: number, gravity: number, time: number): Vector3
	return origin + direction * speed * time - Vector3.yAxis * 0.5 * gravity * time * time
end

function Ballistics.Cast(gunData: GetGun.GunData, origin: Vector3, direction: Vector3, params: RaycastParams): Cast
	const speed = Ballistics.Speed(gunData)
	const gravity = workspace.Gravity * Ballistics.Drop(gunData)
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
			return { Result = result, EndPos = result.Position, Travel = travelled / speed }
		end
		travelled += offset.Magnitude
		previous = point
	end

	return { Result = nil, EndPos = previous, Travel = duration }
end

return Ballistics
