# Visuals: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_visuals"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"preset": "Tarkov",
	"strength": 0.7,
	"sharpen": 0.25,
	"compare_key": "F3",
}

const PRESETS := ["None", "Tarkov", "Zone", "Cold", "Warm Film", "Vivid", "Noir"]
const N := 32

static var _luts := {}


static func _luma(c: Color) -> float:
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722


static func _sat(c: Color, s: float) -> Color:
	var l := _luma(c)
	return Color(lerpf(l, c.r, s), lerpf(l, c.g, s), lerpf(l, c.b, s))


static func _curve(v: float, k: float) -> float:   # gentle S-curve, k = strength
	var s := v * v * (3.0 - 2.0 * v)
	return lerpf(v, s, k)


# One colour through a preset.
static func grade(preset: String, c: Color) -> Color:
	var l := _luma(c)
	match preset:
		"Tarkov":     # teal shadows, warm highlights, a little flatter colour
			c = _sat(c, 0.85)
			c = c.lerp(Color(c.r * 0.92, c.g * 1.0, c.b * 1.08), 1.0 - l)
			c = c.lerp(Color(c.r * 1.06, c.g * 1.01, c.b * 0.92), l)
			c = Color(_curve(c.r, 0.35), _curve(c.g, 0.35), _curve(c.b, 0.35))
		"Zone":       # dusty yellow-green, drained
			c = _sat(c, 0.7)
			c = Color(c.r * 1.03, c.g * 1.04, c.b * 0.86)
			c = Color(_curve(c.r, 0.2), _curve(c.g, 0.2), _curve(c.b, 0.2))
		"Cold":       # blue-grey northern light
			c = _sat(c, 0.8)
			c = Color(c.r * 0.93, c.g * 0.98, c.b * 1.08)
		"Warm Film":  # warm with lifted blacks
			c = Color(c.r * 1.06, c.g * 1.0, c.b * 0.9)
			c = Color(0.04 + c.r * 0.96, 0.035 + c.g * 0.96, 0.03 + c.b * 0.96)
			c = _sat(c, 0.95)
		"Vivid":      # richer colour, a touch of contrast
			c = _sat(c, 1.25)
			c = Color(_curve(c.r, 0.25), _curve(c.g, 0.25), _curve(c.b, 0.25))
		"Noir":
			var g := _curve(l, 0.5)
			c = Color(g, g, g * 1.02)
	return Color(clampf(c.r, 0, 1), clampf(c.g, 0, 1), clampf(c.b, 0, 1))


# A 3D colour lookup table for the environment, blended by strength.
static func lut(preset: String, strength: float) -> ImageTexture3D:
	var key := "%s:%.2f" % [preset, strength]
	if _luts.has(key):
		return _luts[key]
	var slices: Array[Image] = []
	for b in N:
		var img := Image.create(N, N, false, Image.FORMAT_RGB8)
		for g in N:
			for r in N:
				var c := Color(r / float(N - 1), g / float(N - 1), b / float(N - 1))
				img.set_pixel(r, g, c.lerp(grade(preset, c), clampf(strength, 0.0, 1.0)))
		slices.append(img)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGB8, N, N, N, false, slices)
	_luts[key] = tex
	return tex


static func release() -> void:
	_luts.clear()

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
