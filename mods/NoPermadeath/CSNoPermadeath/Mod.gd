# No Permadeath: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_no_permadeath"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
}

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
	if typeof(v) == typeof(fallback) or (typeof(fallback) == TYPE_FLOAT and typeof(v) == TYPE_INT):
		return v
	return fallback


static func say(text: String) -> void:
	var c := cs()
	if c:
		c.log_message(MOD_ID, text)
	else:
		print("[%s] %s" % [MOD_ID, text])
