--!strict
export type Recoil = { Pitch: number, Yaw: number }

const BY_GUN: { [string]: Recoil } = {
	Shotgun = { Pitch = 4, Yaw = 1 },
	["Double Cob"] = { Pitch = 4, Yaw = 1 },
	Sniperagus = { Pitch = 6, Yaw = 0.8 },
	Snipine = { Pitch = 5, Yaw = 0.8 },
	Peavolver = { Pitch = 3, Yaw = 0.6 },
	M6Bean = { Pitch = 0.9, Yaw = 0.4 },
	WatermeLMG = { Pitch = 0.8, Yaw = 0.5 },
	Uzichinni = { Pitch = 0.6, Yaw = 0.5 },
	Raygun = { Pitch = 1.2, Yaw = 0.3 },
	Carrocket = { Pitch = 5, Yaw = 1 },
	["Gromato Launcher"] = { Pitch = 4, Yaw = 0.8 },
	["Chilli Thrower"] = { Pitch = 0.2, Yaw = 0.2 },
	Strawborry = { Pitch = 1.5, Yaw = 0.3 },
}

const DEFAULT: Recoil = { Pitch = 1, Yaw = 0.4 }

const UI_SHAKE_PER_SECOND = 0.5
const UI_SHAKE_MIN = 0.12
const UI_SHAKE_MAX = 0.6

return {
	Scale = 0.09375,
	AimMultiplier = 0.6,
	RecoverRate = 10,
	MaxPitch = 12,
	MaxYaw = 4,
	UIShakeFor = function(fireRate: number): number
		return math.clamp(fireRate * UI_SHAKE_PER_SECOND, UI_SHAKE_MIN, UI_SHAKE_MAX)
	end,
	For = function(gunName: string): Recoil
		return BY_GUN[gunName] or DEFAULT
	end,
}
