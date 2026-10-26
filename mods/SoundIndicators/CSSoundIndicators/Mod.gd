# Sound Indicators: shared helpers. Static, so it survives scene changes.
extends RefCounted

const MOD_ID := "cs_sound_indicators"
const VERSION := "1.0.1"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"gunshots": true,
	"footsteps": true,
	"shot_min": 15.0,
	"shot_max": 300.0,
	"step_max": 40.0,
	"icon_size": 14.0,
	"circle_size": 120.0,
	"my_crouch": 0.6,
	"my_walk": 0.85,
	"my_run": 1.0,
	"ai_step_range": 1.5,
	"close_reset": 10.0,
}

const OVERLAY = preload("res://CSSoundIndicators/Overlay.gd")

# Self-test hooks: values here win over the player's settings.
static var overrides := {}


static func cs() -> Object:
	return Engine.get_meta("Cleanstrike") if Engine.has_meta("Cleanstrike") else null


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


# The overlay on the current map (made on first use).
static func overlay() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	var ui = tree.current_scene.get_node_or_null("/root/Map/Core/UI") if tree and tree.current_scene else null
	if ui == null:
		return null
	var o = ui.get_node_or_null("CS_SoundIndicators")
	if o == null:
		o = OVERLAY.new()
		o.name = "CS_SoundIndicators"
		ui.add_child(o)
	return o


# A sound worth showing: "shot" or "step", at a world position.
static func ping(kind: String, at: Vector3, distance: float) -> bool:
	if not active():
		return false
	if kind == "shot":
		if not bool(setting("gunshots")) or distance < float(setting("shot_min")) or distance > float(setting("shot_max")):
			return false
	elif not bool(setting("footsteps")) or distance > float(setting("step_max")):
		return false
	var o = overlay()
	if o == null:
		return false
	o.add_mark(kind, at)
	return true
