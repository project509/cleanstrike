# CleanStrike HUD: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_hud"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"bars": true,
	"numbers": false,
	"hide_full": true,        # stamina and temperature bars only when not full
	"hide_game_vitals": true, # the bars replace the game's vitals text
	"compass": true,
	"dot": false,             # centre dot at start
	"dot_key": "O",
	"hide_key": "F2",
	"scale": 1.0,
}

const OVERLAY = preload("res://CSHUD/Overlay.gd")

static var dot_on := false
static var dot_init := false
static var hidden := false


static func key_pressed(event: InputEvent, setting_key: String) -> bool:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	var k := OS.find_keycode_from_string(str(setting(setting_key)))
	return k != KEY_NONE and event.physical_keycode == k


static func burst_mod_on() -> bool:
	var c := cs()
	return c != null and c.is_loaded("cs_burst_fire")

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
