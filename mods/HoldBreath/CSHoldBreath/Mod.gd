# Hold Breath: shared helpers and the breath itself (one per player).
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_hold_breath"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"breath_key": "Sprint key",
	"steadiness": 0.75,
	"max_hold": 8.0,
	"stamina_drain": 8.0,
	"recover": 3.0,
}

# Self-test hooks: values here win over the player's settings.
static var overrides := {}

# The breath: holding now, for how long, and recovery afterwards.
static var holding := false
static var held_for := 0.0
static var recovering := 0.0
static var gasping := false
static var sway := 1.0           # current sway multiplier (eased)


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


static func key_down() -> bool:
	if overrides.has("held"):
		return bool(overrides["held"])
	var name := str(setting("breath_key")).strip_edges()
	if name == "" or name.to_lower() == "sprint key":
		return Input.is_action_pressed("sprint")
	var code := OS.find_keycode_from_string(name)
	return code != KEY_NONE and Input.is_key_pressed(code)


# Advance the breath one physics step. Called once per frame by whichever
# weapon is in hand. Returns the sway multiplier for this frame.
static func step(gd, delta: float) -> float:
	var aiming: bool = bool(overrides["aiming"]) if overrides.has("aiming") else gd.isAiming
	var want: bool = aiming and not gd.isRunning and not gd.freeze and key_down()
	if holding:
		held_for += delta
		gd.armStamina = maxf(0.0, float(gd.armStamina) - float(setting("stamina_drain")) * delta)
		var out_of_breath: bool = held_for >= float(setting("max_hold")) or float(gd.armStamina) <= 0.0
		if not want or out_of_breath:
			holding = false
			gasping = out_of_breath
			recovering = float(setting("recover")) * (1.0 if out_of_breath else clampf(held_for / float(setting("max_hold")), 0.3, 1.0))
	elif recovering > 0.0:
		recovering = maxf(0.0, recovering - delta)
		if recovering == 0.0:
			gasping = false
	elif want and float(gd.armStamina) > 5.0:
		holding = true
		held_for = 0.0
	var target := 1.0
	if holding:
		target = 1.0 - clampf(float(setting("steadiness")), 0.0, 0.95)
	elif gasping:
		target = 1.6
	sway = lerpf(sway, target, clampf(delta * 8.0, 0.0, 1.0))
	return sway


static func reset() -> void:
	holding = false
	held_for = 0.0
	recovering = 0.0
	gasping = false
	sway = 1.0
