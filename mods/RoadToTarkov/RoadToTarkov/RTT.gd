# Road to Tarkov: shared state and helpers used by every script extension.
# Static so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "road_to_tarkov"
const VERSION := "0.2.0"

# Defaults; each one can be changed in the Cleanstrike app (settings.json).
const DEFAULTS := {
	"search_enabled": true,
	"search_speed": 1.0,
	"search_corpses": true,
	"examine_enabled": true,
	"examine_speed": 1.0,
	"item_colors": true,
	"reveal_sound": true,
	"customs_enabled": true,
}

# Tarkov-style cell background tints, keyed by RTV item type.
const TYPE_TINTS := {
	"Weapon": Color(0.10, 0.10, 0.10, 0.55),
	"Attachment": Color(0.14, 0.15, 0.16, 0.45),
	"Ammo": Color(0.30, 0.24, 0.10, 0.40),
	"Grenade": Color(0.40, 0.14, 0.08, 0.40),
	"Knife": Color(0.12, 0.12, 0.12, 0.45),
	"Medical": Color(0.45, 0.10, 0.10, 0.40),
	"Consumables": Color(0.20, 0.32, 0.12, 0.40),
	"Consumable": Color(0.20, 0.32, 0.12, 0.40),
	"Electronics": Color(0.10, 0.22, 0.42, 0.42),
	"Key": Color(0.45, 0.38, 0.06, 0.45),
	"Lore": Color(0.48, 0.28, 0.06, 0.42),
	"Armor": Color(0.18, 0.22, 0.14, 0.45),
	"Helmet": Color(0.18, 0.22, 0.14, 0.45),
	"Rig": Color(0.18, 0.22, 0.14, 0.45),
	"Backpack": Color(0.18, 0.22, 0.14, 0.45),
	"Belt Pouch": Color(0.18, 0.22, 0.14, 0.45),
	"Clothing": Color(0.20, 0.20, 0.17, 0.40),
	"Fish": Color(0.10, 0.28, 0.30, 0.40),
	"Fishing": Color(0.10, 0.28, 0.30, 0.40),
	"Instrument": Color(0.30, 0.20, 0.12, 0.40),
	"Literature": Color(0.26, 0.22, 0.16, 0.40),
}
const DEFAULT_TINT := Color(0.22, 0.22, 0.22, 0.30)
const LEGENDARY_TINT := Color(0.36, 0.12, 0.48, 0.50)
const SEARCH_TINT := Color(1, 1, 1, 0.04)

static var _known := {}
static var _loaded := false
static var _seeded := false


# ---------------------------------------------------------------- state

static func cs() -> Object:
	return Engine.get_meta("Cleanstrike") if Engine.has_meta("Cleanstrike") else null


# True when the mod should change behaviour. If Cleanstrike loaded the mod
# but a script failed, it reports the mod as not loaded and we stay vanilla.
static func active() -> bool:
	var c := cs()
	return c == null or c.is_loaded(MOD_ID)


static func setting(key: String):
	var c := cs()
	var fallback = DEFAULTS.get(key)
	if c == null:
		return fallback
	var v = c.get_setting(MOD_ID, key, fallback)
	return v if typeof(v) == typeof(fallback) or (typeof(fallback) == TYPE_FLOAT and typeof(v) == TYPE_INT) else fallback


static func searching() -> bool:
	return active() and bool(setting("search_enabled"))


static func customs_enabled() -> bool:
	return active() and bool(setting("customs_enabled"))


static func examining() -> bool:
	return active() and bool(setting("examine_enabled"))


static func say(text: String) -> void:
	var c := cs()
	if c:
		c.log_message(MOD_ID, text)
	else:
		print("[RoadToTarkov] " + text)


# ---------------------------------------------------------------- knowledge

static func _data_path() -> String:
	var c := cs()
	var dir: String = c.get_data_dir(MOD_ID) if c else "user://road_to_tarkov"
	if c == null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	return dir.path_join("knowledge.json")


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var path := _data_path()
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(data) == TYPE_DICTIONARY:
			for f in data.get("known", []):
				_known[str(f)] = true
			_seeded = bool(data.get("seeded", false))


static func _save() -> void:
	var f := FileAccess.open(_data_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version": 1, "seeded": _seeded, "known": _known.keys()}, "  "))


static func is_seeded() -> bool:
	_load()
	return _seeded


static func mark_seeded() -> void:
	_load()
	_seeded = true
	_save()


static func knows(file: String) -> bool:
	_load()
	return _known.has(file)


# Returns true if this was new knowledge.
static func learn(file: String, save := true) -> bool:
	_load()
	if file == "" or _known.has(file):
		return false
	_known[file] = true
	if save:
		_save()
	return true


static func learn_many(files: Array) -> int:
	var added := 0
	for f in files:
		if learn(str(f), false):
			added += 1
	if added > 0:
		_save()
	return added


static func known_count() -> int:
	_load()
	return _known.size()


# Is this UI Item (or SlotData) something the player has not examined yet?
static func is_unknown(item) -> bool:
	if not examining() or item == null:
		return false
	var sd = item.slotData if item is Control else item
	if sd == null or sd.itemData == null:
		return false
	return not knows(sd.itemData.file)


static func is_hidden(item) -> bool:
	return item != null and is_instance_valid(item) and bool(item.get_meta("rtt_hidden", false))


# ---------------------------------------------------------------- timing

static func _rarity_index(data) -> int:
	return int(data.rarity) if "rarity" in data else 0


static func search_time(data) -> float:
	var cells := maxf(1.0, data.size.x * data.size.y)
	var t := 0.35 + 0.16 * cells
	var r := _rarity_index(data)
	if r == 1:
		t += 0.35
	elif r == 2:
		t += 0.8
	return t / maxf(0.1, float(setting("search_speed")))


static func examine_time(data) -> float:
	var cells := maxf(1.0, data.size.x * data.size.y)
	var t := 1.2 + 0.12 * cells
	var r := _rarity_index(data)
	if r == 1:
		t += 0.6
	elif r == 2:
		t += 1.2
	return t / maxf(0.1, float(setting("examine_speed")))


# ---------------------------------------------------------------- visuals

static func tint_for(data) -> Color:
	if data == null:
		return DEFAULT_TINT
	if _rarity_index(data) == 2:
		return LEGENDARY_TINT
	return TYPE_TINTS.get(str(data.type).strip_edges(), DEFAULT_TINT)


static func should_search(container) -> bool:
	if not searching() or container == null:
		return false
	if bool(container.get("furniture")):
		return false   # the player's own storage
	if bool(container.get("corpse")) and not bool(setting("search_corpses")):
		return false
	return true
