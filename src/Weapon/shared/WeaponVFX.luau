--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Set = {
	Muzzle: string?,
	Tracer: string?,
	Impact: string,
	Flame: string?,
	Trail: string?,
}

export type Muzzle = { Anchor: BasePart, Offset: CFrame }

export type PelletKind = "None" | "Wall" | "Player" | "Head"

export type Pellet = { EndPos: Vector3, Normal: Vector3, Kind: PelletKind, Delay: number? }

const WALL = "ImpactWall"

const DEFAULT_SET: Set = { Impact = WALL }

const SETS: { [string]: Set } = {
	Shotgun = { Muzzle = "Muzzle_Shotgun", Impact = WALL },
	Peavolver = { Muzzle = "Muzzle_Default", Tracer = "Tracer_Bullet", Impact = "Impact_Peavolver" },
	Uzichinni = { Muzzle = "Muzzle_Uzichinni", Tracer = "Tracer_Bullet", Impact = "Impact_Uzichinni" },
	M6Bean = { Muzzle = "Muzzle_M6Bean", Tracer = "Tracer_Bullet", Impact = "Impact_M6Bean" },
	WatermeLMG = { Muzzle = "Muzzle_WatermeLMG", Tracer = "Tracer_Bullet", Impact = "Impact_WatermeLMG" },
	Snipine = { Muzzle = "Muzzle_Snipine", Tracer = "Tracer_Sniper", Impact = "Impact_Snipine" },
	Sniperagus = { Muzzle = "Muzzle_Sniperagus", Tracer = "Tracer_Sniper", Impact = "Impact_Sniperagus" },
	Strawborry = { Trail = "Tracer_Arrow", Impact = "Impact_Strawborry" },
	Raygun = { Muzzle = "Muzzle_Default", Impact = "Impact_Raygun" },
	Carrocket = { Muzzle = "Muzzle_Launcher", Impact = WALL, Trail = "Trail_Carrocket" },
	["Gromato Launcher"] = { Muzzle = "Muzzle_Launcher", Impact = WALL },
	["Chilli Thrower"] = { Flame = "Flame_Chilli", Impact = WALL },
}

const FOLDER = "VFX"

const warned: { [string]: boolean } = {}
const muzzles: { [Model]: Muzzle } = setmetatable({}, { __mode = "k" }) :: any

const WeaponVFX = {}

WeaponVFX.IMPACT_WALL = WALL
WeaponVFX.IMPACT_PLAYER = "ImpactPlayer"
WeaponVFX.IMPACT_HEADSHOT = "ImpactPlayerHeadshot"
WeaponVFX.SCREEN_FIRE = "ScreenFire"
WeaponVFX.SCREEN_HIT = "ScreenHit"
WeaponVFX.SCREEN_HEAL = "ScreenHeal"
WeaponVFX.HEAL_BODY = "HealBody"
WeaponVFX.BURNING_ATTRIBUTE = "Burning"
WeaponVFX.LOOP_ATTRIBUTE = "Loop"
WeaponVFX.EMIT_ATTRIBUTE = "EmitCount"
WeaponVFX.HEAVY_DAMAGE = 30

function WeaponVFX.For(gunName: string): Set
	return SETS[gunName] or DEFAULT_SET
end

function WeaponVFX.Template(name: string): BasePart?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const folder = if assets then assets:FindFirstChild(FOLDER) else nil
	const template = if folder then folder:FindFirstChild(name) else nil
	if template and template:IsA("BasePart") then
		return template
	end

	if not warned[name] then
		warned[name] = true
		warn(`[WeaponVFX] Assets.VFX.{name} nao encontrado`)
	end

	return nil
end

function WeaponVFX.EmitCount(emitter: ParticleEmitter): number
	const count = emitter:GetAttribute(WeaponVFX.EMIT_ATTRIBUTE)
	return if typeof(count) == "number" and count > 0 then math.max(math.round(count), 1) else 1
end

local function dominantAxis(box: CFrame, size: Vector3, forward: Vector3): (Vector3, number)
	local axis = box.LookVector
	local half = size.Z * 0.5
	local best = axis:Dot(forward)

	const right = box.RightVector:Dot(forward)
	if math.abs(right) > math.abs(best) then
		axis, half, best = box.RightVector, size.X * 0.5, right
	end

	const up = box.UpVector:Dot(forward)
	if math.abs(up) > math.abs(best) then
		axis, half, best = box.UpVector, size.Y * 0.5, up
	end

	return if best < 0 then -axis else axis, half
end

function WeaponVFX.MuzzleAttachment(model: Model): Attachment?
	for _, descendant in model:GetDescendants() do
		if descendant.Name == "Muzzle" and descendant:IsA("Attachment") then
			const parent = descendant.Parent
			if parent and parent:IsA("BasePart") then
				return descendant
			end
		end
	end

	return nil
end

function WeaponVFX.Muzzle(model: Model, forward: Vector3): Muzzle?
	const cached = muzzles[model]
	if cached and cached.Anchor:IsDescendantOf(model) then
		return cached
	end

	const marked = WeaponVFX.MuzzleAttachment(model)
	if marked then
		const muzzle: Muzzle = { Anchor = marked.Parent :: BasePart, Offset = marked.CFrame }
		muzzles[model] = muzzle
		return muzzle
	end

	const anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not anchor or forward.Magnitude < 0.001 then
		return nil
	end

	const unit = forward.Unit
	const box, size = model:GetBoundingBox()
	const axis, half = dominantAxis(box, size, unit)
	const tip = box.Position + axis * half
	const muzzle: Muzzle = { Anchor = anchor, Offset = anchor.CFrame:ToObjectSpace(CFrame.lookAt(tip, tip + axis)) }
	muzzles[model] = muzzle
	return muzzle
end

function WeaponVFX.MuzzleCFrame(model: Model, forward: Vector3): CFrame?
	const muzzle = WeaponVFX.Muzzle(model, forward)
	return if muzzle then muzzle.Anchor.CFrame * muzzle.Offset else nil
end

return WeaponVFX
