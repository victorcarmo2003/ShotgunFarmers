--!strict
export type Effect = "None" | "Shrapnel" | "Gas" | "Acid" | "Fire" | "Boomerang"

export type ZoneSpec = {
	Radius: number,
	Height: number,
	Duration: number,
	Dps: number,
	LingerSeconds: number,
	LingerDps: number,
	SpeedMultiplier: number,
	Visual: string,
	Color: Color3,
}

export type ShrapnelSpec = {
	Count: number,
	Damage: number,
	Range: number,
}

export type Definition = {
	Name: string,
	Fuse: number,
	Contact: boolean,
	Radius: number,
	DamageCenter: number,
	DamageEdge: number,
	Speed: number,
	Lift: number,
	GravityScale: number,
	Bounciness: number,
	Friction: number,
	CurveAngle: number,
	MaxRange: number?,
	Direct: boolean?,
	Drop: number?,
	Spin: Vector3,
	Effect: Effect,
	Zone: ZoneSpec?,
	Shrapnel: ShrapnelSpec?,
	ExplosionVisual: string,
	Sound: string,
	Color: Color3,
	FaceVelocity: boolean?,
	ProjectileModel: string?,
}

const DEFINITIONS: { [string]: Definition } = {
	Pinapple = {
		Name = "Pinapple",
		Fuse = 2.5,
		Contact = false,
		Radius = 15,
		DamageCenter = 90,
		DamageEdge = 20,
		Speed = 65,
		Lift = 12,
		GravityScale = 0.8,
		Bounciness = 0.4,
		Friction = 0.85,
		CurveAngle = 0,
		Spin = Vector3.new(8, 3, 0),
		Effect = "Shrapnel",
		Shrapnel = { Count = 4, Damage = 15, Range = 22 },
		ExplosionVisual = "PinappleExplosion",
		Sound = "PinappleExplosion",
		Color = Color3.fromRGB(230, 190, 60),
	},
	Onionnade = {
		Name = "Onionnade",
		Fuse = 2,
		Contact = false,
		Radius = 14,
		DamageCenter = 15,
		DamageEdge = 15,
		Speed = 65,
		Lift = 12,
		GravityScale = 0.8,
		Bounciness = 0.4,
		Friction = 0.85,
		CurveAngle = 0,
		Spin = Vector3.new(7, 5, 0),
		Effect = "Gas",
		Zone = {
			Radius = 12,
			Height = 10,
			Duration = 6,
			Dps = 5,
			LingerSeconds = 4,
			LingerDps = 0,
			SpeedMultiplier = 1,
			Visual = "OnionGas",
			Color = Color3.fromRGB(190, 160, 220),
		},
		ExplosionVisual = "OnionnadeExplosion",
		Sound = "OnionnadeExplosion",
		Color = Color3.fromRGB(200, 170, 230),
	},
	Lemonade = {
		Name = "Lemonade",
		Fuse = 2,
		Contact = false,
		Radius = 12,
		DamageCenter = 20,
		DamageEdge = 20,
		Speed = 65,
		Lift = 12,
		GravityScale = 0.8,
		Bounciness = 0.4,
		Friction = 0.85,
		CurveAngle = 0,
		Spin = Vector3.new(7, 5, 0),
		Effect = "Acid",
		Zone = {
			Radius = 10,
			Height = 5,
			Duration = 6,
			Dps = 8,
			LingerSeconds = 0,
			LingerDps = 0,
			SpeedMultiplier = 0.6,
			Visual = "LemonAcid",
			Color = Color3.fromRGB(200, 240, 60),
		},
		ExplosionVisual = "LemonadeExplosion",
		Sound = "LemonadeExplosion",
		Color = Color3.fromRGB(240, 230, 80),
	},
	Moolotov = {
		Name = "Moolotov",
		Fuse = 5,
		Contact = true,
		Radius = 10,
		DamageCenter = 10,
		DamageEdge = 10,
		Speed = 65,
		Lift = 10,
		GravityScale = 1,
		Bounciness = 0,
		Friction = 0,
		CurveAngle = 0,
		Spin = Vector3.new(10, 2, 0),
		Effect = "Fire",
		Zone = {
			Radius = 9,
			Height = 5,
			Duration = 6,
			Dps = 12,
			LingerSeconds = 3,
			LingerDps = 4,
			SpeedMultiplier = 1,
			Visual = "MolotovFire",
			Color = Color3.fromRGB(255, 120, 30),
		},
		ExplosionVisual = "MolotovExplosion",
		Sound = "MolotovExplosion",
		Color = Color3.fromRGB(255, 255, 255),
	},
	Bananarang = {
		Name = "Bananarang",
		Fuse = 4,
		Contact = true,
		Radius = 10,
		DamageCenter = 80,
		DamageEdge = 20,
		Speed = 60,
		Lift = 0,
		GravityScale = 0.1,
		Bounciness = 0,
		Friction = 0,
		CurveAngle = math.rad(24),
		MaxRange = 140,
		Drop = 0.04,
		Spin = Vector3.new(0, 22, 0),
		Effect = "Boomerang",
		ExplosionVisual = "BananaExplosion",
		Sound = "BananaExplosion",
		Color = Color3.fromRGB(250, 220, 70),
	},
}

const LAUNCHERS: { [string]: Definition } = {
	Carrocket = {
		Name = "Carrocket",
		Fuse = 500 / 160,
		Contact = true,
		Radius = 8,
		DamageCenter = 100,
		DamageEdge = 30,
		Speed = 160,
		Lift = 0,
		GravityScale = 0,
		Bounciness = 0,
		Friction = 0,
		CurveAngle = 0,
		Spin = Vector3.zero,
		Effect = "None",
		ExplosionVisual = "Explosion_Carrocket",
		Sound = "GrenadeExplosion",
		Color = Color3.fromRGB(255, 140, 40),
		FaceVelocity = true,
		ProjectileModel = "CarrocketMissile",
	},
	["Gromato Launcher"] = {
		Name = "Gromato Launcher",
		Fuse = 300 / 110,
		Contact = true,
		Radius = 7,
		DamageCenter = 70,
		DamageEdge = 20,
		Speed = 110,
		Lift = 10,
		GravityScale = 0.35,
		Bounciness = 0,
		Friction = 0,
		CurveAngle = 0,
		Spin = Vector3.new(6, 0, 0),
		Effect = "None",
		ExplosionVisual = "GrenadeExplosion",
		Sound = "GrenadeExplosion",
		Color = Color3.fromRGB(220, 50, 40),
		ProjectileModel = "GromatoShell",
	},
	Strawborry = {
		Name = "Strawborry",
		Fuse = 3,
		Contact = true,
		Radius = 0,
		DamageCenter = 60,
		DamageEdge = 60,
		Speed = 190,
		Lift = 0,
		GravityScale = 0.45,
		Bounciness = 0,
		Friction = 0,
		CurveAngle = 0,
		Spin = Vector3.zero,
		Effect = "None",
		ExplosionVisual = "Impact_Strawborry",
		Sound = "HitWall1",
		Color = Color3.fromRGB(235, 70, 90),
		FaceVelocity = true,
		ProjectileModel = "StrawborryArrow",
		Direct = true,
	},
}

for name, definition in LAUNCHERS do
	DEFINITIONS[name] = definition
end

const Throwables = {}

Throwables.SELF_DAMAGE_SCALE = 0.5
Throwables.THROW_POWERS = { 0.5, 0.75, 1 }
Throwables.SHORT_THROW = 1
Throwables.MEDIUM_THROW = 2
Throwables.LONG_THROW = 3
Throwables.PROJECTILE_RADIUS = 0.5
Throwables.STEP = 1 / 60
Throwables.ZONE_DAMAGE_INTERVAL = 1
Throwables.ZONE_SCAN_INTERVAL = 0.2
Throwables.ZONE_FLOOR_TOLERANCE = 2
Throwables.ZONE_GROUND_PROBE = 30
Throwables.FOLDER_NAME = "Throwables"

Throwables.All = DEFINITIONS

function Throwables.Get(name: string): Definition?
	return DEFINITIONS[name]
end

function Throwables.Falloff(definition: Definition, distance: number): number
	const alpha = math.clamp(distance / definition.Radius, 0, 1)
	return definition.DamageCenter + (definition.DamageEdge - definition.DamageCenter) * alpha
end

function Throwables.InsideZone(zone: ZoneSpec, center: Vector3, point: Vector3): boolean
	const offset = point - center
	if offset.Y < -Throwables.ZONE_FLOOR_TOLERANCE or offset.Y > zone.Height then
		return false
	end

	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= zone.Radius
end

return Throwables
