# Airdrops: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_airdrops"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"smoke_minutes": 3.0,
	"night_glow": true,
}


# A thick column of red smoke rising from a landed crate.
static func make_smoke(minutes: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "CS_RedSmoke"
	p.amount = 160
	p.lifetime = 9.0
	p.visibility_aabb = AABB(Vector3(-15, -2, -15), Vector3(30, 60, 30))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 4.5
	pm.gravity = Vector3(0.4, 0.25, 0.0)          # a little drift, keeps rising
	pm.scale_min = 1.0
	pm.scale_max = 2.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 3.0))
	pm.scale_curve = CurveTexture.new()
	pm.scale_curve.curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.85, 0.12, 0.08, 0.85))
	fade.set_color(1, Color(0.55, 0.15, 0.12, 0.0))
	pm.color_ramp = GradientTexture1D.new()
	pm.color_ramp.gradient = fade
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _puff_texture()
	quad.material = mat
	p.draw_pass_1 = quad
	p.emitting = true
	p.set_meta("cs_stop_at", Time.get_ticks_msec() + int(minutes * 60000.0))
	return p


# A soft round puff, made once.
static var _puff: ImageTexture
static func _puff_texture() -> ImageTexture:
	if _puff == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))
		_puff = ImageTexture.create_from_image(img)
	return _puff

# Self-test hook: values here win over the player's settings.
static var overrides := {}


static func cs() -> Object:
	return Engine.get_meta("Cleanstrike") if Engine.has_meta("Cleanstrike") else null


# False when Cleanstrike rolled this mod back: stay vanilla.
static func active() -> bool:
	var c := cs()
	return c == null or c.is_loaded(MOD_ID)


static func setting(key: String):
	if overrides.has(key):
		return overrides[key]
	var fallback = DEFAULTS.get(key)
	var c := cs()
	if c == null:
		return fallback
	var v = c.get_setting(MOD_ID, key, fallback)
	# Settings files store every number as a float: convert to the default's type.
	if typeof(fallback) == TYPE_INT and typeof(v) == TYPE_FLOAT:
		return int(round(v))
	if typeof(fallback) == TYPE_FLOAT and typeof(v) == TYPE_INT:
		return float(v)
	return v if typeof(v) == typeof(fallback) else fallback


static func say(text: String) -> void:
	var c := cs()
	if c:
		c.log_message(MOD_ID, text)
	else:
		print("[%s] %s" % [MOD_ID, text])
