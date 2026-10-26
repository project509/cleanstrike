# Weather and Seasons: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_weather_seasons"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"seasons": true,
	"summer_days": 10,
	"winter_days": 5,
	"w_neutral": 59,     # the game: 1 aurora, 10 storm, 10 rain, 10 overcast, 10 wind, 59 neutral
	"w_rain": 10,
	"w_storm": 10,
	"w_overcast": 10,
	"w_wind": 10,
	"w_aurora": 1,
	"min_minutes": 5.0,
	"max_minutes": 20.0,
}

const WEATHERS := {"Neutral": "w_neutral", "Rain": "w_rain", "Storm": "w_storm",
	"Overcast": "w_overcast", "Wind": "w_wind", "Aurora": "w_aurora"}

static var _state := {}       # days in this season, pending season
static var _loaded := false


static func roll_weather() -> Array:
	var total := 0
	for w in WEATHERS:
		total += maxi(0, int(setting(WEATHERS[w])))
	var pick := "Neutral"
	if total > 0:
		var r := randi_range(1, total)
		for w in WEATHERS:
			r -= maxi(0, int(setting(WEATHERS[w])))
			if r <= 0:
				pick = w
				break
	var lo := maxf(0.5, float(setting("min_minutes")))
	var hi := maxf(lo, float(setting("max_minutes")))
	return [pick, randf_range(lo, hi) * 60.0]


static func _path() -> String:
	var c := cs()
	var dir: String = c.get_data_dir(MOD_ID) if c else "user://cleanstrike/data/" + MOD_ID
	return dir.path_join("season.json")


static func state() -> Dictionary:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(_path()):
			var d = JSON.parse_string(FileAccess.get_file_as_string(_path()))
			if d is Dictionary:
				_state = d
	return _state


static func _save() -> void:
	var gd = load("res://Resources/GameData.tres")
	if gd.tutorial:
		return
	DirAccess.make_dir_recursive_absolute(_path().get_base_dir())
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_state))


static func season_length(season: int) -> int:
	return maxi(1, int(setting("summer_days" if season == 1 else "winter_days")))


# A day passed: when the season has run its length, the other one is due.
static func new_day(season: int) -> bool:
	var st := state()
	st["days"] = int(st.get("days", 0)) + 1
	var due := false
	if int(st.days) >= season_length(season) and not st.has("pending"):
		st["pending"] = 2 if season == 1 else 1
		due = true
		var tree := Engine.get_main_loop() as SceneTree
		var loader = tree.root.get_node_or_null("Loader") if tree else null
		if loader and loader.has_method("Message"):
			loader.Message("Winter is coming: it arrives when you next travel" if season == 1 else "The thaw is coming: summer arrives when you next travel", Color.LIGHT_BLUE)
	_save()
	return due


# On a map change: the season to use now.
static func take_pending(season: int) -> int:
	var st := state()
	if not st.has("pending"):
		return season
	var s := int(st.pending)
	st.erase("pending")
	st["days"] = 0
	_save()
	return s

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


static func reset() -> void:
	_state = {}
	_loaded = true
	_save()
