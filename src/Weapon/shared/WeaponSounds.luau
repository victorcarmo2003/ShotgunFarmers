--!strict
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

export type Pool = { Sounds: { Sound }, Next: number }

export type Outcome = "Victory" | "Defeat" | "Draw"

const SHOOT: { [string]: string } = {
	Shotgun = "ShotgunShoot",
	Peavolver = "Revolver",
	Uzichinni = "AutoPistol",
	M6Bean = "M4",
	WatermeLMG = "WatermelonMG",
	Sniperagus = "Sniper1",
	Snipine = "Sniper2",
	Strawborry = "BowShoot",
	Raygun = "Laser",
	Carrocket = "Bazooka",
	["Gromato Launcher"] = "Bazooka",
}

export type CycleSound = { Sound: string, Equip: number?, AfterShot: number, Marker: string? }

const DRAW: { [string]: CycleSound } = {
	Strawborry = { Sound = "BowDraw", Equip = 0, AfterShot = 0, Marker = "DrawArrow" },
}

const PUMP: { [string]: CycleSound } = {
	Shotgun = { Sound = "ShotgunPump", AfterShot = 0.25 },
}

const TRIM: { [string]: number } = {
	Sniper1 = 0.12,
}

const HIT_PREFIX = "Hit"
const WALL_PREFIX = "HitWall"
const HIT_VARIANTS = 9
const POOL_SIZE = 3
const MAX_POSITIONAL = 16
const MIN_LIFETIME = 1

const warned: { [string]: boolean } = {}
const pools: { [Instance]: { [string]: Pool } } = {}
local positionalCount = 0

const WeaponSounds = {}

WeaponSounds.Shoot = SHOOT
WeaponSounds.Draw = DRAW
WeaponSounds.Pump = PUMP
WeaponSounds.TRIM = TRIM
WeaponSounds.MATCH_END = "MatchEnd"
WeaponSounds.OUTCOME_ATTRIBUTE = "MatchOutcome"
WeaponSounds.OUTCOMES = { "Victory", "Defeat", "Draw" } :: { Outcome }

function WeaponSounds.Template(name: string): Sound?
	if name == "" then
		return nil
	end

	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const sounds = if assets then assets:FindFirstChild("Sounds") else nil
	const sound = if sounds then sounds:FindFirstChild(name) else nil
	if sound and sound:IsA("Sound") then
		return sound
	end

	if not warned[name] then
		warned[name] = true
		warn(`[WeaponSounds] Assets.Sounds.{name} nao encontrado`)
	end

	return nil
end

function WeaponSounds.ShootName(gunName: string): string
	return SHOOT[gunName] or ""
end

function WeaponSounds.DrawName(gunName: string): string
	const entry = DRAW[gunName]
	return if entry then entry.Sound else ""
end

function WeaponSounds.PumpName(gunName: string): string
	const entry = PUMP[gunName]
	return if entry then entry.Sound else ""
end

function WeaponSounds.DrawTiming(gunName: string): CycleSound?
	return DRAW[gunName]
end

function WeaponSounds.PumpTiming(gunName: string): CycleSound?
	return PUMP[gunName]
end

function WeaponSounds.RandomHit(): string
	return `{HIT_PREFIX}{math.random(1, HIT_VARIANTS)}`
end

function WeaponSounds.RandomWall(): string
	return `{WALL_PREFIX}{math.random(1, HIT_VARIANTS)}`
end

local function poolFor(parent: Instance, name: string): Pool
	local byName = pools[parent]
	if not byName then
		const created: { [string]: Pool } = {}
		byName = created
		pools[parent] = created
		parent.Destroying:Once(function()
			pools[parent] = nil
		end)
	end

	local pool = byName[name]
	if not pool then
		const created: Pool = { Sounds = {}, Next = 0 }
		pool = created
		byName[name] = created
	end

	return pool
end

function WeaponSounds.PlayPooled(name: string, parent: Instance)
	const template = WeaponSounds.Template(name)
	if not template then
		return
	end

	const pool = poolFor(parent, name)
	pool.Next = pool.Next % POOL_SIZE + 1

	local sound = pool.Sounds[pool.Next]
	if not sound or sound.Parent ~= parent then
		const clone = template:Clone()
		clone.Parent = parent
		pool.Sounds[pool.Next] = clone
		sound = clone
	end

	sound.TimePosition = TRIM[name] or 0
	sound:Play()
end

function WeaponSounds.PlayAt(name: string, position: Vector3)
	if positionalCount >= MAX_POSITIONAL then
		return
	end

	const template = WeaponSounds.Template(name)
	if not template then
		return
	end

	const anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = workspace.Terrain

	const sound = template:Clone()
	sound.Parent = anchor
	sound.TimePosition = TRIM[name] or 0
	sound:Play()

	positionalCount += 1
	const lifetime = math.max(sound.TimeLength, MIN_LIFETIME) + 0.5
	anchor.Destroying:Once(function()
		positionalCount -= 1
	end)
	Debris:AddItem(anchor, lifetime)
end

function WeaponSounds.Play2D(name: string)
	const template = WeaponSounds.Template(name)
	if template then
		template.TimePosition = TRIM[name] or 0
		SoundService:PlayLocalSound(template)
	end
end

return WeaponSounds
