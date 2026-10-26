# AI Overhaul: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_ai_overhaul"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"accuracy": 1.0,          # spread multiplier for everyone (lower = deadlier)
	"bandit_spread": 1.25,
	"guard_spread": 1.0,
	"military_spread": 0.8,
	"bandit_sight": 0.85,
	"guard_sight": 1.0,
	"military_sight": 1.15,
	"weather_cover": true,    # rain and storms make you harder to see
	"crouch_cover": true,     # crouching makes you harder to see and hear
	"burst_range": 15.0,      # enemies go full auto this close (m)
	"self_heal": true,
	"heal_amount": 30.0,
	"heal_cooldown": 30.0,
}

# AIData.Faction: Nomad 0, Bandit 1, Guard 2, Military 3, Boss 4
const KEYS := {1: "bandit", 2: "guard", 3: "military"}


static func spread_mult(faction: int) -> float:
	var m := float(setting("accuracy"))
	if KEYS.has(faction):
		m *= float(setting(KEYS[faction] + "_spread"))
	return m


static func sight_mult(faction: int) -> float:
	return float(setting(KEYS[faction] + "_sight")) if KEYS.has(faction) else 1.0


# A point around the target, spread across the real line of fire (the game
# spreads along the gun node's last orientation, which can point down the
# line of fire and shrink the spread, so accuracy depended on facing).
static func spread_point(from: Vector3, target: Vector3, offset: float) -> Vector3:
	var dir := (target - from).normalized()
	if dir == Vector3.ZERO:
		return target
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.01:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(dir).normalized()
	return target + side * randf_range(-offset, offset) + up * randf_range(-offset, offset)


# How far an AI can see / hear you, given faction, weather and your stance.
static func view_factor(gd, faction: int, weather: String) -> float:
	var f := sight_mult(faction)
	if bool(setting("weather_cover")):
		f *= {"Rain": 0.85, "Storm": 0.7, "Overcast": 0.95}.get(weather, 1.0)
	if bool(setting("crouch_cover")) and gd.isCrouching:
		f *= 0.8
	return f


static func hear_factor(gd) -> float:
	return 0.6 if bool(setting("crouch_cover")) and gd.isCrouching else 1.0

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
