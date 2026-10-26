# Injuries Rework: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_injuries_rework"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"bleed_dps": 0.5,          # health per second while bleeding (game: 0.2)
	"bleed_seconds": 30.0,     # a bleed stops by itself after this (0 = never)
	"fracture_dps": 0.07,      # slow drain from a fracture (game: 0.2)
	"fracture_run_dps": 2.0,   # extra while running on a fracture
	"rupture_hunger": 3.0,     # food and water drain this many times faster
	"headshot_bleed": "none",  # none, short (bleeds like a wound), vanilla (bleeds until treated)
	"burn_damage": true,
	"injury_mental": true,     # injuries wear on your mind (game)
}


# Health lost this tick from the injuries this mod handles.
static func drain(gd, delta: float) -> float:
	var d := 0.0
	if gd.bleeding:
		d += float(setting("bleed_dps")) * delta
	if gd.fracture:
		d += float(setting("fracture_dps")) * delta
		if gd.isRunning:
			d += float(setting("fracture_run_dps")) * delta
	return d

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
