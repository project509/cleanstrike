# Progression: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_progression"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"xp_rate": 1.0,           # multiplier on all XP
	"shelter_only": false,    # spend points only in a shelter
	"messages": true,
}

const MAX_RANK := 5
# key: [name, what one rank does]
const SKILLS := {
	"endurance": ["Endurance", "Sprinting drains 6% less stamina"],
	"strength": ["Strength", "Carry 2 kg more"],
	"metabolism": ["Metabolism", "Hunger and thirst 6% slower"],
	"steady": ["Steady Hands", "Aiming drains 8% less arm stamina"],
	"scavenger": ["Scavenger", "5% chance of an extra find in containers"],
	"barter": ["Barter", "Trader tax 3% lower"],
}
const PER_RANK := {"endurance": 0.06, "strength": 2.0, "metabolism": 0.06, "steady": 0.08, "scavenger": 0.05, "barter": 3.0}
const KILL_XP := {1: 25, 2: 40, 3: 60, 4: 200, 0: 20}   # by AIData.Faction

# Self-test hooks: values here win over the player's settings.
static var overrides := {}
static var _state := {}
static var _loaded := false


static func _path() -> String:
	var c := cs()
	var dir: String = c.get_data_dir(MOD_ID) if c else "user://cleanstrike/data/" + MOD_ID
	return dir.path_join("progress.json")


static func state() -> Dictionary:
	if not _loaded:
		_loaded = true
		_state = {}
		if FileAccess.file_exists(_path()):
			var d = JSON.parse_string(FileAccess.get_file_as_string(_path()))
			if d is Dictionary:
				_state = d
	for k in ["xp", "level", "points"]:
		if not _state.has(k):
			_state[k] = 1 if k == "level" else 0
	if not _state.has("ranks"):
		_state["ranks"] = {}
	return _state


static func _save() -> void:
	var gd = load("res://Resources/GameData.tres")
	if gd.tutorial:
		return
	DirAccess.make_dir_recursive_absolute(_path().get_base_dir())
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_state))


static func level() -> int:
	return int(state().level)


# XP needed to go from this level to the next.
static func need(lvl: int) -> int:
	return int(round(100.0 * pow(lvl, 1.5)))


static func rank(skill: String) -> int:
	return int(state().ranks.get(skill, 0)) if active() else 0


static func bonus(skill: String) -> float:
	return rank(skill) * float(PER_RANK[skill])


static func add_xp(amount: float, reason: String) -> int:
	if not active() or amount <= 0.0:
		return 0
	var st := state()
	var got := int(round(amount * float(setting("xp_rate"))))
	st.xp = int(st.xp) + got
	var ups := 0
	while int(st.xp) >= need(int(st.level)):
		st.xp = int(st.xp) - need(int(st.level))
		st.level = int(st.level) + 1
		st.points = int(st.points) + 1
		ups += 1
	_save()
	if bool(setting("messages")):
		_message("+%d XP  %s" % [got, reason], Color(0.75, 0.85, 1.0))
		if ups > 0:
			_message("Level %d!  Skill point to spend (Character > Skills)" % int(st.level), Color(0.95, 0.8, 0.3))
	return ups


static func can_spend(skill: String) -> bool:
	var gd = load("res://Resources/GameData.tres")
	if bool(setting("shelter_only")) and not gd.shelter:
		return false
	return int(state().points) > 0 and rank(skill) < MAX_RANK


static func spend(skill: String) -> bool:
	if not can_spend(skill):
		return false
	var st := state()
	st.ranks[skill] = rank(skill) + 1
	st.points = int(st.points) - 1
	_save()
	return true


# A new game (or a permadeath wipe) starts over.
static func wipe() -> void:
	_state = {}
	_loaded = true
	if FileAccess.file_exists(_path()):
		DirAccess.remove_absolute(_path())


static func _message(text: String, color: Color) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var loader = tree.root.get_node_or_null("Loader") if tree else null
	if loader and loader.has_method("Message"):
		loader.Message(text, color)


# Give back part of a drain (a negative change) to a GameData stat.
static func ease_drain(gd, stat: String, before: float, part: float) -> void:
	var change: float = float(gd.get(stat)) - before
	if change < 0.0 and part > 0.0:
		gd.set(stat, float(gd.get(stat)) - change * minf(part, 0.9))


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
