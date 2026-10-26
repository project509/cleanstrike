# Reticles: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_reticles"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"style": "Optic default",
	"color": "Red",
	"brightness": 1.0,
	"style_key": "U",
	"color_key": "J",
}

# The game's red-dot reticle materials (scope reticles are left alone).
const MATERIALS := ["res://Items/Attachments/Common/Optics/MT_RDS.tres",
	"res://Items/Attachments/EXPS/Files/MT_EXPS_Reticle.tres",
	"res://Items/Attachments/Kobra/Files/MT_Kobra_Reticle.tres"]
const STYLES := ["Optic default", "Dot", "Circle dot", "Chevron", "Cross", "Circle cross", "Triangle"]
# Pure colours: the sight boosts brightness several times, so any mixed-in
# channel washes towards white.
const COLORS := {"Red": Color(1.0, 0.0, 0.0), "Green": Color(0.0, 1.0, 0.05), "Amber": Color(1.0, 0.35, 0.0),
	"Blue": Color(0.0, 0.3, 1.0), "White": Color(0.6, 0.6, 0.6), "Magenta": Color(1.0, 0.0, 0.6)}
const GAME_SHADER := "res://Shaders/Reticle.gdshader"

static var _shader: Shader
static var _orig := {}        # material path -> [shader, texture, intensity]
static var _tex := {}
static var picked := {}       # in-game choices (style/color), saved
static var _picked_loaded := false


static func _path() -> String:
	var c := cs()
	var dir: String = c.get_data_dir(MOD_ID) if c else "user://cleanstrike/data/" + MOD_ID
	return dir.path_join("choice.json")


static func choice(key: String) -> String:
	if not _picked_loaded:
		_picked_loaded = true
		if FileAccess.file_exists(_path()):
			var d = JSON.parse_string(FileAccess.get_file_as_string(_path()))
			if d is Dictionary:
				picked = d
	if overrides.has(key):
		return str(overrides[key])
	return str(picked.get(key, setting(key)))


# The game's reticle shader with a colour instead of fixed red. It is made
# from the game's own shader at runtime; none of it ships with the mod.
static func shader() -> Shader:
	if _shader == null:
		var base: Shader = load(GAME_SHADER)
		var code := base.code
		var red := "reticleSample.rgb * vec3(intensity, 0.0, 0.0)"
		var anchor := "uniform float intensity"
		if not (red in code) or not (anchor in code):
			return null
		code = code.replace(anchor, "uniform vec3 cs_tint = vec3(1.0, 0.0, 0.0);\n" + anchor)
		code = code.replace(red, "vec3(max(reticleSample.r, max(reticleSample.g, reticleSample.b))) * cs_tint * intensity")
		_shader = Shader.new()
		_shader.code = code
	return _shader


# Reticle shapes, drawn once at 512 px in white (the shader colours them).
static func texture(style: String) -> Texture2D:
	if _tex.has(style):
		return _tex[style]
	var n := 512
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n / 2.0, n / 2.0)
	for y in range(96, n - 96):          # shapes stay within 160 px of the centre
		for x in range(96, n - 96):
			var a := _shape(style, Vector2(x + 0.5, y + 0.5) - c)
			if a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_tex[style] = ImageTexture.create_from_image(img)
	return _tex[style]


static func _line(p: Vector2, a: Vector2, b: Vector2, w: float) -> float:
	var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return clampf(w - p.distance_to(a.lerp(b, t)) + 0.5, 0.0, 1.0)


static func _ring(d: float, r: float, w: float) -> float:
	return clampf(w - absf(d - r) + 0.5, 0.0, 1.0)


static func _shape(style: String, p: Vector2) -> float:
	var d := p.length()
	var dot := clampf(9.0 - d + 0.5, 0.0, 1.0)
	match style:
		"Dot":
			return dot
		"Circle dot":
			return maxf(dot, _ring(d, 110.0, 5.0))
		"Chevron":
			return maxf(_line(p, Vector2(0, -6), Vector2(-60, 54), 5.0), _line(p, Vector2(0, -6), Vector2(60, 54), 5.0))
		"Cross":
			var arms := maxf(maxf(_line(p, Vector2(-90, 0), Vector2(-22, 0), 4.0), _line(p, Vector2(22, 0), Vector2(90, 0), 4.0)),
				maxf(_line(p, Vector2(0, -90), Vector2(0, -22), 4.0), _line(p, Vector2(0, 22), Vector2(0, 90), 4.0)))
			return maxf(arms, clampf(5.0 - d + 0.5, 0.0, 1.0))
		"Circle cross":
			var ticks := maxf(maxf(_line(p, Vector2(-130, 0), Vector2(-90, 0), 4.0), _line(p, Vector2(90, 0), Vector2(130, 0), 4.0)),
				maxf(_line(p, Vector2(0, -130), Vector2(0, -90), 4.0), _line(p, Vector2(0, 90), Vector2(0, 130), 4.0)))
			return maxf(maxf(_ring(d, 110.0, 5.0), ticks), dot)
		"Triangle":
			var t1 := _line(p, Vector2(0, -40), Vector2(-40, 30), 4.0)
			var t2 := _line(p, Vector2(0, -40), Vector2(40, 30), 4.0)
			var t3 := _line(p, Vector2(-40, 30), Vector2(40, 30), 4.0)
			return maxf(maxf(t1, t2), t3)
	return 0.0


static func apply() -> void:
	var sh := shader()
	for path in MATERIALS:
		if not ResourceLoader.exists(path):
			continue
		var m: ShaderMaterial = load(path)
		if not _orig.has(path):
			_orig[path] = [m.shader, m.get_shader_parameter("reticle"), float(m.get_shader_parameter("intensity"))]
		var stock := choice("style") == "Optic default" and choice("color") == "Red" and is_equal_approx(float(setting("brightness")), 1.0)
		if not active() or sh == null or stock:   # untouched: the game's own shader
			_restore(m, path)
			continue
		var params := {}
		for k in ["scope", "opacity", "size"]:
			params[k] = m.get_shader_parameter(k)
		m.shader = sh
		for k in params:
			m.set_shader_parameter(k, params[k])
		var style := choice("style")
		m.set_shader_parameter("reticle", _orig[path][1] if style == "Optic default" or not (style in STYLES) else texture(style))
		m.set_shader_parameter("cs_tint", COLORS.get(choice("color"), COLORS.Red))
		m.set_shader_parameter("intensity", _orig[path][2] * float(setting("brightness")))


static func _restore(m: ShaderMaterial, path: String) -> void:
	m.shader = _orig[path][0]
	m.set_shader_parameter("reticle", _orig[path][1])
	m.set_shader_parameter("intensity", _orig[path][2])


static func key_event(event: InputEvent, key: String) -> bool:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	var k := OS.find_keycode_from_string(str(setting(key)))
	return k != KEY_NONE and event.physical_keycode == k


static func cycle(key: String, options: Array) -> String:
	var i := options.find(choice(key))
	var next: String = options[(i + 1) % options.size()]
	picked[key] = next
	DirAccess.make_dir_recursive_absolute(_path().get_base_dir())
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(picked))
	apply()
	var tree := Engine.get_main_loop() as SceneTree
	var loader = tree.root.get_node_or_null("Loader") if tree else null
	if loader and loader.has_method("Message"):
		loader.Message("Reticle: %s, %s" % [choice("style"), choice("color")], Color.WHITE)
	return next


static func release() -> void:
	for path in _orig:
		_restore(load(path), path)
	_orig.clear()
	_tex.clear()
	_shader = null

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
