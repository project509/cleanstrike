# Gear Spawns: shared helpers (settings, attachment rolls, night gear).
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_gear_spawns"
const VERSION := "1.0.0"

const KINDS := ["Optic", "Muzzle", "Laser"]   # scope, suppressor, laser
const KEYS := {"Optic": "scope", "Muzzle": "suppressor", "Laser": "laser"}

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"bandit_scope": 10, "bandit_suppressor": 5, "bandit_laser": 8,
	"guard_scope": 20, "guard_suppressor": 10, "guard_laser": 15,
	"military_scope": 40, "military_suppressor": 20, "military_laser": 30,
	"world_scope": 8, "world_suppressor": 4, "world_laser": 6,
	"world_magazine": 40, "magazine_fill_min": 5, "magazine_fill_max": 80,
	"unlock_scope": 10, "unlock_suppressor": 30, "unlock_laser": 5, "early_chance": 2,
	"night_gear": true,
	"bandit_flashlight": 20, "guard_flashlight": 40, "military_flashlight": 60,
	"bandit_nvg": 0, "guard_nvg": 5, "military_nvg": 30,
	"bandit_sight": 20.0, "guard_sight": 35.0, "military_sight": 60.0,
}

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


static func say(text: String) -> void:
	var c := cs()
	if c:
		c.log_message(MOD_ID, text)
	else:
		print("[%s] %s" % [MOD_ID, text])


static func day() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var sim = tree.root.get_node_or_null("Simulation") if tree else null
	return int(sim.day) if sim else 1


# Settings group for a faction: bandits and nomads alike, bosses as military.
static func group(faction: String) -> String:
	match faction:
		"Guard": return "guard"
		"Military", "Boss": return "military"
		"World": return "world"
	return "bandit"


# Chance (0-100) of a kind of attachment for a group, today. Before its
# unlock day it's rare (early_chance).
static func chance(group_name: String, kind: String) -> float:
	var key: String = KEYS[kind]
	var c := float(setting("%s_%s" % [group_name, key]))
	if day() < int(setting("unlock_" + key)):
		c = minf(c, float(setting("early_chance")))
	return c


# Attachments to add to a weapon (ItemData list), at most one of each kind,
# none of a kind it already has.
static func roll_attachments(weapon_data, group_name: String, has: Array) -> Array:
	var out := []
	if weapon_data == null or not ("compatible" in weapon_data):
		return out
	for kind in KINDS:
		if kind in has or randf() * 100.0 >= chance(group_name, kind):
			continue
		var options := []
		for a in weapon_data.compatible:
			if a and str(a.subtype) == kind:
				options.append(a)
		if not options.is_empty():
			out.append(options.pick_random())
	return out


# A found weapon: maybe a loaded magazine, maybe attachments.
static func kit_found_weapon(slot) -> void:
	if not active() or slot == null or slot.itemData == null or str(slot.itemData.type) != "Weapon":
		return
	var wd = slot.itemData
	var has := []
	for n in slot.nested:
		if n:
			has.append(str(n.subtype))
	if not ("Magazine" in has) and "compatible" in wd and wd.compatible.size() > 0 and wd.compatible[0] \
			and str(wd.compatible[0].subtype) == "Magazine" and randf() * 100.0 < float(setting("world_magazine")):
		slot.nested.append(wd.compatible[0])
		var size := int(wd.magazineSize) if "magazineSize" in wd else 0
		var lo := int(setting("magazine_fill_min"))
		var hi := maxi(lo, int(setting("magazine_fill_max")))
		slot.amount = int(round(size * randi_range(lo, hi) / 100.0))
	for a in roll_attachments(wd, "world", has):
		slot.nested.append(a)


static func is_night() -> bool:
	var gd = load("res://Resources/GameData.tres")
	return int(gd.TOD) == 4
