# Tarkov Looting: shared state and helpers used by every script extension.
# (Extracted from Road to Tarkov; developed on its own from here.)
# Static so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "tarkov_looting"
const VERSION := "1.2.1"

# Defaults; each one can be changed in the Cleanstrike app (settings.json).
const DEFAULTS := {
	"search_enabled": true,
	"search_speed": 1.0,
	"search_corpses": true,
	"examine_enabled": true,
	"examine_speed": 1.0,
	"examine_middle_mouse": true,
	"search_sounds": true,
	"pause_while_dragging": true,
	"character_affects_search": true,
	"worn_gear_visible": true,
	"value_borders": true,
	"item_colors": true,
	"reveal_sound": true,
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

# Unknown items of these types (or subtypes) still work (equip, use, load, attach), as in
# Tarkov: you can fight with a gun you haven't examined.
const USABLE_UNKNOWN := ["Weapon", "Magazine", "Knife", "Grenade"]

# Flat silhouettes: unknown items show only their outline (no detail, no
# colour); the next item being searched shows as a faint grey ghost.
const SILHOUETTE_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.1, 0.1, 0.1, 1.0);
varying vec4 vcolor;
void vertex() {
	vcolor = COLOR;   // fragment COLOR already includes the texture colour
}
void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(tint.rgb * vcolor.rgb, a * tint.a * vcolor.a);
}
"""
const SILHOUETTE_UNKNOWN := Color(0.11, 0.11, 0.105, 0.95)
const SILHOUETTE_PREVIEW := Color(0.55, 0.55, 0.53, 0.30)

static var _materials := {}
static var _sounds := {}


# Our own sounds (generated, see tools/make_loot_sounds.py). Raw WAVs in the
# mod archive aren't imported resources, so build the stream from the bytes.
static func sound(name: String) -> AudioStream:
	if not _sounds.has(name):
		var bytes := FileAccess.get_file_as_bytes("res://TarkovLooting/Sounds/%s.wav" % name)
		_sounds[name] = AudioStreamWAV.load_from_buffer(bytes) if bytes.size() > 44 else null
	return _sounds[name]
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
	# Settings files store every number as a float: convert to the default's type.
	if typeof(fallback) == TYPE_INT and typeof(v) == TYPE_FLOAT:
		return int(round(v))
	if typeof(fallback) == TYPE_FLOAT and typeof(v) == TYPE_INT:
		return float(v)
	return v if typeof(v) == typeof(fallback) else fallback


static func searching() -> bool:
	return active() and bool(setting("search_enabled"))


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


# Unknown and not one of the types that work anyway.
static func is_restricted(item) -> bool:
	if not is_unknown(item):
		return false
	var sd = item.slotData if item is Control else item
	var d = sd.itemData
	# Magazines are type "Attachment", subtype "Magazine".
	return not (str(d.type).strip_edges() in USABLE_UNKNOWN or str(d.get("subtype")).strip_edges() in USABLE_UNKNOWN)


static func silhouette(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if not _materials.has(key):
		var shader := Shader.new()
		shader.code = SILHOUETTE_SHADER
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("tint", color)
		_materials[key] = m
	return _materials[key]


static func is_hidden(item) -> bool:
	return item != null and is_instance_valid(item) and bool(item.get_meta("tl_hidden", false))


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
	return t * character_factor() / maxf(0.1, float(setting("search_speed")))


# Searching is slower when the character is in a bad way.
static func character_factor() -> float:
	if not bool(setting("character_affects_search")):
		return 1.0
	var gd = load("res://Resources/GameData.tres")
	var f := 1.0
	if gd.overweight: f *= 1.3
	if gd.fracture: f *= 1.4
	if gd.bleeding: f *= 1.15
	if gd.frostbite: f *= 1.25   # numb fingers
	if gd.insanity: f *= 1.15
	return f


# What a body is visibly wearing or carrying needs no searching.
const WORN_TYPES := ["Weapon", "Armor", "Helmet", "Rig", "Backpack", "Clothing", "Belt Pouch"]

static func is_worn_gear(data) -> bool:
	return data != null and str(data.type).strip_edges() in WORN_TYPES


# ---------------------------------------------------------------- value tiers

# Value per cell, compared with the game's whole loot table: top 5% gold,
# top 20% purple, top 40% blue. Anything below gets no border.
const VALUE_COLORS := [Color(0.95, 0.75, 0.25), Color(0.68, 0.42, 0.95), Color(0.35, 0.62, 0.95)]
static var _value_cuts := []

static func value_color(data) -> Color:
	if data == null or not bool(setting("value_borders")):
		return Color.TRANSPARENT
	if _value_cuts.is_empty():
		var vals := []
		for it in load("res://Loot/LT_Master.tres").items:
			vals.append(_per_cell(it))
		vals.sort()
		if vals.is_empty():
			return Color.TRANSPARENT
		for q in [0.95, 0.8, 0.6]:
			_value_cuts.append(vals[int((vals.size() - 1) * q)])
	var v := _per_cell(data)
	for i in 3:
		if v >= _value_cuts[i] and v > 0.0:
			return VALUE_COLORS[i]
	return Color.TRANSPARENT


static func _per_cell(data) -> float:
	return float(data.value) / maxf(1.0, data.size.x * data.size.y)


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
