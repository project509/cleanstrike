# Loot Settings: shared helpers and the loot roll used by containers and
# floor loot. Static, so it works without an autoload and survives scenes.
extends RefCounted

const MOD_ID := "cs_loot_settings"
const VERSION := "1.0.0"

const PRESETS := ["Vanilla", "Balanced", "Loot Overhaul", "Mega Loot", "Custom"]

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
# The numbers are used by the Custom preset; they start at the game's own.
const DEFAULTS := {
	"preset": "Balanced",
	"common_chance": 0.20,
	"common_max": 4,
	"rare_chance": 0.04,
	"rare_max": 1,
	"legendary_chance": 0.001,
	"jackpot_chance": 0.01,
	"reroll_empty": 0.5,
	"add_chance": 0.3,
	"add_min": 1,
	"add_max": 5,
	"condition_min": 25,
	"condition_max": 100,
	"stashes_always": false,
	"no_empty_cans": false,
	"key_weight": 1.0,
}

# What each preset means. Vanilla isn't here: it leaves the game alone.
#  Balanced: the game's chances, plus a second roll for empty containers and
#    a 30% chance of 1-5 extra items (Loot Modifier's defaults).
#  Loot Overhaul: 70% of containers hold something, always at least one
#    item, rare items more often alongside common ones, more medical.
#  Mega Loot: much more of everything, every stash on the map with a
#    legendary inside, keys more common, no empty cans.
const PRESET_VALUES := {
	"Balanced": {},
	"Loot Overhaul": {"common_chance": 0.56, "common_max": 4, "common_min": 1, "rare_chance": 0.12, "rare_max": 1,
		"rare_min": 1, "legendary_chance": 0.002, "reroll_empty": 0.0, "add_chance": 0.0, "rare_with_common": 0.25,
		"medical_bonus": 0.3},
	"Mega Loot": {"common_chance": 0.45, "common_max": 6, "common_min": 2, "rare_chance": 0.15, "rare_max": 2,
		"rare_min": 1, "legendary_chance": 0.01, "jackpot_chance": 0.05, "reroll_empty": 0.5, "add_chance": 0.5,
		"add_max": 6, "stashes_always": true, "stash_legendary": true, "no_empty_cans": true, "key_weight": 4.0},
}

# Self-test hook: values here win over the player's settings.
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


# ---------------------------------------------------------------- tuning

static func preset() -> String:
	var p := str(setting("preset"))
	return p if p in PRESETS else "Balanced"


# Is the mod changing loot at all?
static func changes_loot() -> bool:
	return active() and preset() != "Vanilla"


# A tuning value for the current preset (Custom: the player's numbers).
static func value(key: String):
	var p := preset()
	if p == "Custom":
		return setting(key) if DEFAULTS.has(key) else _extra_default(key)
	var table: Dictionary = PRESET_VALUES.get(p, {})
	if table.has(key):
		return table[key]
	return DEFAULTS[key] if DEFAULTS.has(key) else _extra_default(key)


static func _extra_default(key: String):
	match key:
		"common_min", "rare_min": return 0
		"rare_with_common", "medical_bonus": return 0.0
		"stash_legendary": return false
	return null


# ---------------------------------------------------------------- rolling

# One container's (or floor spot's) loot, as a list of ItemData.
# Same shape as the game's roll: a legendary, a few rare items, a handful of
# common ones, or the rare jackpot with all three. corpse: bodies roll from a
# better range, like the game (its 1-30 roll is ~3.3x the chances).
static func roll(common: Array, rare: Array, legendary: Array, joker := false, corpse := false) -> Array:
	var out := _roll_once(common, rare, legendary, joker, corpse)
	if out.is_empty() and randf() < float(value("reroll_empty")):
		out = _roll_once(common, rare, legendary, joker, corpse)
	if randf() < float(value("add_chance")) and not common.is_empty():
		for i in randi_range(int(value("add_min")), int(value("add_max"))):
			out.append(_pick(common))
	return out


static func _roll_once(common: Array, rare: Array, legendary: Array, joker: bool, corpse: bool) -> Array:
	var out := []
	var boost := 100.0 / 30.0 if corpse else 1.0
	var r := randf()
	var pl := float(value("legendary_chance")) * boost
	var pj := 0.0 if corpse else float(value("jackpot_chance"))   # a body's 1-30 roll never hits 100
	var pr := float(value("rare_chance")) * boost
	var pc := float(value("common_chance")) * boost
	if joker or r < pj:
		if not legendary.is_empty() and randf() < 0.1:
			out.append(legendary.pick_random())
		for i in randi_range(1, 2):
			if not rare.is_empty():
				out.append(_pick(rare))
		for i in randi_range(4, 10):
			if not common.is_empty():
				out.append(_pick(common))
		return out
	r -= pj
	if r < pl:
		if not legendary.is_empty():
			out.append(legendary.pick_random())
		return out
	r -= pl
	if r < pr:
		for i in randi_range(int(value("rare_min")), int(value("rare_max"))):
			if not rare.is_empty():
				out.append(_pick(rare))
		return out
	r -= pr
	if r < pc:
		for i in randi_range(int(value("common_min")), int(value("common_max"))):
			if not common.is_empty():
				out.append(_pick(common))
		if not rare.is_empty() and randf() < float(value("rare_with_common")):
			out.append(_pick(rare))
		var medical := common.filter(func(it): return str(it.type) == "Medical")
		if not medical.is_empty() and randf() < float(value("medical_bonus")):
			out.append(medical.pick_random())
	return out


# Weighted pick: keys can be made more common, empty cans removed.
static func _pick(items: Array):
	var no_cans := bool(value("no_empty_cans"))
	for attempt in 8:
		var it = items.pick_random()
		if no_cans and it and str(it.file) == "Can_Empty":
			continue
		return it
	return items.pick_random()


static func weighted(items: Array) -> Array:
	# Keys more common: repeat them in the pool.
	var key_w := float(value("key_weight"))
	if key_w <= 1.0:
		return items
	var out := items.duplicate()
	for it in items:
		if it and str(it.type) == "Key":
			for i in int(round(key_w)) - 1:
				out.append(it)
	return out


static func condition() -> float:
	var lo := int(value("condition_min"))
	var hi := maxi(lo, int(value("condition_max")))
	return float(randi_range(lo, hi))
