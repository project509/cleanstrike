# Faction Warfare: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_faction_warfare"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"side": "Neutral",            # Neutral, Bandit, Guard, Military
	"bandit_infighting": true,
	"guard_infighting": false,
	"military_infighting": false,
	"rivals": 30,                 # % of each zone's enemies from a rival faction
	"density": 1.0,               # more enemies at once (x)
}

# AIData.Faction: Nomad 0, Bandit 1, Guard 2, Military 3, Boss 4
const NOMAD := 0
const BANDIT := 1
const GUARD := 2
const MILITARY := 3
const BOSS := 4
const NAMES := {"Bandit": BANDIT, "Guard": GUARD, "Military": MILITARY}
const RIVAL_SCENES := {BANDIT: ["res://AI/Guard/AI_Guard.tscn"],
	GUARD: ["res://AI/Bandit/AI_Bandit.tscn", "res://AI/Military/AI_Military.tscn"],
	MILITARY: ["res://AI/Guard/AI_Guard.tscn"]}


# Does faction a attack faction b?
static func hostile(a: int, b: int) -> bool:
	if a == NOMAD or b == NOMAD:
		return a != b                  # nomads and everyone else, as in the game
	if a == BOSS or b == BOSS:
		return false                   # bosses keep to their own business
	if a == b:
		return bool(setting({BANDIT: "bandit_infighting", GUARD: "guard_infighting", MILITARY: "military_infighting"}.get(a, "bandit_infighting")))
	return true


# Is this faction on the player's side?
static func allied(faction: int) -> bool:
	return NAMES.get(str(setting("side")), -1) == faction

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
