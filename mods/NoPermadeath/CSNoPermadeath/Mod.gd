# No Permadeath: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_no_permadeath"
const VERSION := "1.0.0"

const LOSE_ALL := "Lose everything"
const KEEP_WORN := "Keep worn gear and weapons"
const KEEP_ALL := "Keep everything"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"zones": true,
	"hardcore": true,
	"on_death": LOSE_ALL,
	"keep_on_quit": false,
}

const CHARACTER := "user://Character.tres"

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


# ---------------------------------------------------------------- permadeath

# Is permadeath switched off for this difficulty? Hardcore (difficulty 3)
# makes every map permadeath; otherwise only the Vostok zones are.
static func spares(difficulty: int) -> bool:
	if not active():
		return false
	return bool(setting("hardcore")) if difficulty == 3 else bool(setting("zones"))


static func keep_mode() -> String:
	var m := str(setting("on_death"))
	return m if m in [LOSE_ALL, KEEP_WORN, KEEP_ALL] else LOSE_ALL


# ---------------------------------------------------------------- gear

# The character as it is right now (the game's own save routine, read back
# without the resource cache).
static func capture_character() -> CharacterSave:
	Loader.SaveCharacter()
	return ResourceLoader.load(CHARACTER, "", ResourceLoader.CACHE_MODE_IGNORE) as CharacterSave


# After the game has reset the character for a death, put back what the
# player keeps. Stats stay reset (you come back at full health), weapons
# holstered, reputation and the cat as the game left them.
static func restore_gear(kept: CharacterSave, mode: String, path := CHARACTER) -> bool:
	if kept == null or mode == LOSE_ALL:
		return false
	var fresh := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as CharacterSave
	if fresh == null:
		return false
	fresh.equipment = kept.equipment
	if mode == KEEP_ALL:
		fresh.inventory = kept.inventory
		fresh.catalog = kept.catalog
	var err := ResourceSaver.save(fresh, path)
	say("Kept on death (%s): %d equipped, %d carried, %d catalog." % [mode, fresh.equipment.size(), fresh.inventory.size(), fresh.catalog.size()])
	return err == OK
