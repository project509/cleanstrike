# Kill Counter: shared helpers and the tally (kept per save).
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_kill_counter"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"messages": true,
	"panel": true,
}

# Self-test hooks: values here win over the player's settings.
static var overrides := {}
static var _tally := {}
static var _loaded := false


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


static func _path() -> String:
	var c := cs()
	var dir: String = c.get_data_dir(MOD_ID) if c else "user://cleanstrike/data/" + MOD_ID
	return dir.path_join("kills.json")


static func tally() -> Dictionary:
	if not _loaded:
		_loaded = true
		_tally = {}
		if FileAccess.file_exists(_path()):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(_path()))
			if parsed is Dictionary:
				_tally = parsed
	return _tally


static func total() -> int:
	var n := 0
	for k in tally():
		n += int(tally()[k])
	return n


static func add(faction: String) -> int:
	tally()[faction] = int(tally().get(faction, 0)) + 1
	var gd = load("res://Resources/GameData.tres")
	if not gd.tutorial:
		DirAccess.make_dir_recursive_absolute(_path().get_base_dir())
		var f := FileAccess.open(_path(), FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(tally()))
	return int(tally()[faction])


# New game or a permadeath wipe: the count starts over.
static func wipe() -> void:
	_tally = {}
	_loaded = true
	if FileAccess.file_exists(_path()):
		DirAccess.remove_absolute(_path())
