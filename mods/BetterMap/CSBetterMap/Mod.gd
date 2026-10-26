# Better Map: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_better_map"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"you": true,
	"shelters": true,
	"traders": true,
}

# Shelters and the area each one is in (from the game's shelter scenes).
const SHELTERS := {"Attic": "Village", "Cabin": "Village", "Garage": "Highway",
	"Classroom": "School", "Bunker": "Outpost", "Tent": "Outpost"}

const OVERLAY = preload("res://CSBetterMap/Overlay.gd")

static var _met := {}       # trader -> area
static var _loaded := false


static func _path() -> String:
	var c := cs()
	var dir: String = c.get_data_dir(MOD_ID) if c else "user://cleanstrike/data/" + MOD_ID
	return dir.path_join("traders.json")


static func met() -> Dictionary:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(_path()):
			var d = JSON.parse_string(FileAccess.get_file_as_string(_path()))
			if d is Dictionary:
				_met = d
	return _met


# Where the player is: [area marker, label].
static func where() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var m = tree.root.get_node_or_null("Map") if tree else null
	if m == null or not ("mapType" in m):
		return ["", ""]
	if m.mapType == "Shelter":
		return [str(m.shelterLocation), "You (%s)" % m.mapName]
	return [str(m.mapName), "You"]


static func meet(trader: String) -> void:
	var w := where()
	if w[0] == "" or str(w[0]) == "Tutorial" or met().get(trader) == w[0]:
		return
	met()[trader] = w[0]
	DirAccess.make_dir_recursive_absolute(_path().get_base_dir())
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_met))


# What to list under each area: [kind, name].
static func lines() -> Dictionary:
	var out := {}
	if bool(setting("shelters")):
		for s in SHELTERS:
			out[SHELTERS[s]] = out.get(SHELTERS[s], []) + [["shelter", s]]
	if bool(setting("traders")):
		for t in met():
			out[met()[t]] = out.get(met()[t], []) + [["trader", t]]
	return out


# Put the overlay on the world map (once) and point it at the player.
static func show_on(map_rect: Control) -> Node:
	if not active() or map_rect == null:
		return null
	var o = map_rect.get_node_or_null("CS_BetterMap")
	if o == null:
		o = OVERLAY.new()
		o.name = "CS_BetterMap"
		map_rect.add_child(o)
	var w := where()
	o.here = w[0]
	o.here_label = w[1]
	return o

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
