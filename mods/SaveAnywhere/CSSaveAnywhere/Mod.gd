# Save Anywhere: shared helpers and the one-time "suspend" save (map and
# spot you quit at). Static, so it survives scene changes.
extends RefCounted

const MOD_ID := "cs_save_anywhere"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"enabled": true,
}

# Self-test hooks: values here win over the player's settings.
static var overrides := {}
static var pending := {}        # the suspend being resumed right now


static func cs() -> Object:
	return Engine.get_meta("Cleanstrike") if Engine.has_meta("Cleanstrike") else null


static func active() -> bool:
	var c := cs()
	return (c == null or c.is_loaded(MOD_ID)) and bool(setting("enabled"))


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


static func path() -> String:
	var c := cs()
	var dir: String = c.get_data_dir(MOD_ID) if c else "user://cleanstrike/data/" + MOD_ID
	return dir.path_join("suspend.json")


static func write(map_name: String, pos: Vector3, rot_y: float) -> void:
	DirAccess.make_dir_recursive_absolute(path().get_base_dir())
	var f := FileAccess.open(path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"map": map_name, "pos": [pos.x, pos.y, pos.z], "rot": rot_y}))


static func read() -> Dictionary:
	if not FileAccess.file_exists(path()):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path()))
	return d if d is Dictionary and d.has("map") else {}


static func clear() -> void:
	if FileAccess.file_exists(path()):
		DirAccess.remove_absolute(path())
