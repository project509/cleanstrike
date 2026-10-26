# Hideout Lights: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_hideout_lights"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"price": 1.0,          # trader price multiplier
	"brightness": 1.0,
	"shadows": false,      # lights cast shadows (costs frames)
}

const DIR := "res://CSHideoutLights/Files/"
const BASE_F := "res://Assets/Rack_Coat/Rack_Coat_F.tscn"   # a vanilla furniture scene to build on
const WARM := Color(1.0, 0.78, 0.5)
const COOL := Color(0.9, 0.95, 1.0)

# file: [name, source scene, size, wall?, light (omni/spot/none = its own), colour, energy, range, value, traders]
const FIXTURES := {
	"CS_Light_Candle": ["Candle", "res://Assets/Candle/Candle.tscn", Vector2(1, 1), false, "own", WARM, 0.0, 0.0, 60, ["generalist", "doctor"]],
	"CS_Light_Lantern": ["Kerosene Lantern", "res://Assets/Lantern_Kerosene/Lantern_Kerosene.tscn", Vector2(1, 2), false, "own", WARM, 0.0, 0.0, 180, ["generalist", "hunter"]],
	"CS_Light_Floor": ["Floor Lamp", "res://Assets/Lamp_Floor/Lamp_Floor.tscn", Vector2(1, 3), false, "omni", WARM, 1.6, 7.0, 300, ["generalist"]],
	"CS_Light_Tube": ["Tube Light", "res://Assets/Lamp_Generic/Lamp_Generic.tscn", Vector2(2, 1), true, "omni", COOL, 1.4, 8.0, 240, ["gunsmith", "generalist"]],
	"CS_Light_Round": ["Round Light", "res://Assets/Lamp_Round/Lamp_Round.tscn", Vector2(2, 2), true, "omni", WARM, 1.5, 8.0, 260, ["generalist"]],
	"CS_Light_Bulkhead": ["Bulkhead Light", "res://Assets/Lamp_Cellar/Lamp_Cellar.tscn", Vector2(1, 2), true, "omni", WARM, 1.2, 6.0, 220, ["gunsmith"]],
	"CS_Light_Exit": ["Exit Sign", "res://Assets/Sign_Exit/Sign_Exit.tscn", Vector2(2, 1), true, "omni", Color(0.3, 1.0, 0.45), 0.5, 3.0, 150, ["doctor", "gunsmith"]],
}

static var items := {}      # file -> ItemData
static var scenes := {}     # file -> PackedScene (placed fixture)

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
