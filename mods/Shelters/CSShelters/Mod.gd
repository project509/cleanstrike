# Shelters: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_shelters"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"needs_rate": 0.25,        # hunger and thirst inside, x the normal rate (0 = paused)
	"mental_rate": 0.0,        # stress inside
	"cat_rate": 0.5,
	"heal_per_minute": 6.0,    # health back per minute while unhurt and fed
}

const INJURIES := ["bleeding", "fracture", "burn", "poisoning", "rupture", "headshot", "starvation", "dehydration", "frostbite"]


static func inside(gd) -> bool:
	return active() and gd.shelter and not gd.tutorial


# Undo part of a drain that just happened (rate 0 = none of it).
static func slow(gd, stat: String, before: float, rate_key: String) -> void:
	if not inside(gd):
		return
	var change: float = float(gd.get(stat)) - before
	if change < 0.0:
		gd.set(stat, before + change * clampf(float(setting(rate_key)), 0.0, 1.0))


# Healing needs a shelter, no injuries and some food and water in you.
static func resting(gd) -> bool:
	if not inside(gd) or gd.isDead or gd.health >= 100.0:
		return false
	for f in INJURIES:
		if bool(gd.get(f)):
			return false
	return gd.energy > 20.0 and gd.hydration > 20.0

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
