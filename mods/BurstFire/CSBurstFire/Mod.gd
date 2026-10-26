# Burst Fire: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_burst_fire"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"burst_size": 3,
}

const META := "cs_burst"   # on the weapon's SlotData (mode stays 2 = auto, so
                           # without the mod the gun is simply on auto)


static func is_burst(slot) -> bool:
	return active() and slot != null and int(slot.mode) == 2 and bool(slot.get_meta(META, false))


# The fire-mode switch: semi -> auto -> burst -> semi.
static func next_mode(slot) -> void:
	if int(slot.mode) == 1:
		slot.mode = 2
		slot.set_meta(META, false)
	elif int(slot.mode) == 2 and not bool(slot.get_meta(META, false)):
		slot.set_meta(META, true)
	else:
		slot.mode = 1
		slot.set_meta(META, false)

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
