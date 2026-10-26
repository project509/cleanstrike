# Event Hints: shared helpers, event settings and the event pick.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_event_hints"
const VERSION := "1.0.0"

# The game's dynamic events, by the key used in settings.
#   key: [match (event function, or name for the Outpost BTR), default chance %, hint]
const EVENTS := {
	"airdrop": ["Airdrop", 15, "A transport plane drones somewhere overhead..."],
	"helicopter": ["Helicopter", 25, "Rotor blades thump in the distance..."],
	"btr": ["BTR", 25, "The rumble of an armored vehicle carries through the area..."],
	"outpost": ["Outpost gets compromised", 25, "Engines and gunfire near the Outpost..."],
	"crash": ["CrashSite", 15, "Smoke rises on the horizon. Something came down nearby..."],
	"jets": ["FighterJet", 25, "Jets tear across the sky..."],
	"punisher": ["Police", 15, "Police sirens wail in the distance..."],
	"bogeyman": ["Bogeyman", 15, "Something is moving in the dark between the trees..."],
}

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
static var DEFAULTS := _defaults()

# Self-test hooks: values here win over the player's settings.
static var overrides := {}
static var last_hint := ""


static func _defaults() -> Dictionary:
	var d := {"hints": true, "max_delay": 300}
	for key in EVENTS:
		d[key + "_chance"] = int(EVENTS[key][1])
		d[key + "_weight"] = 1.0
		d[key + "_hint"] = key != "helicopter" and key != "jets"
	return d


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


# ---------------------------------------------------------------- events

# Settings key for one of the game's events ("" for events we don't know:
# those keep the game's own chance and a weight of 1).
static func key_of(event) -> String:
	for key in EVENTS:
		var match_on: String = EVENTS[key][0]
		if str(event.name) == match_on:
			return key
	for key in EVENTS:
		if str(event.function) == EVENTS[key][0] and key != "outpost":
			return key
	return ""


static func chance(event) -> int:
	var key := key_of(event)
	return int(setting(key + "_chance")) if key != "" else int(event.possibility)


static func weight(event) -> float:
	var key := key_of(event)
	return maxf(0.0, float(setting(key + "_weight"))) if key != "" else 1.0


static func hint(event) -> String:
	var key := key_of(event)
	if key == "" or not bool(setting("hints")) or not bool(setting(key + "_hint")):
		return ""
	return str(EVENTS[key][2])


# Show the chances in the game's own Events panel too.
static func apply_chances(events: Array) -> void:
	for e in events:
		if e and str(e.type) == "Dynamic" and key_of(e) != "":
			e.possibility = chance(e)


# CleanStrike Fixes Overhaul's fair odds: one roll over every eligible event,
# so each event's chance is exactly what it says (the game picks one event
# first and rolls only that, which divides every chance by the number of
# events). Used when the Fixes Overhaul is on with that fix enabled.
static func fair_odds() -> bool:
	var c := cs()
	if c == null or not c.is_loaded("cs_fixes_overhaul"):
		return false
	return bool(c.get_setting("cs_fixes_overhaul", "event_odds", true))


static func fair_empty() -> float:
	var c := cs()
	return float(c.get_setting("cs_fixes_overhaul", "event_empty", 20.0)) if c else 20.0


# Which event happens this map visit (null for none). pool: the eligible
# dynamic events.
static func choose(pool: Array, fair := false):
	var weighted := pool.filter(func(e): return weight(e) > 0.0)
	if weighted.is_empty():
		return null
	if fair:
		return fair_pick(weighted, fair_empty())
	# The game's way: pick one (by weight), then roll its chance (0-100).
	var total := 0.0
	for e in weighted:
		total += weight(e)
	var r := randf() * total
	var event = weighted[-1]
	for e in weighted:
		r -= weight(e)
		if r < 0.0:
			event = e
			break
	return event if randi_range(0, 100) <= chance(event) else null


# One roll: each event takes its chance-sized slice of 0-100, the rest is
# "nothing". If the chances add up to more than (100 - empty), they're
# scaled down so at least `empty` % of visits stay quiet.
static func fair_pick(events: Array, empty := 20.0):
	var total := 0.0
	for e in events:
		total += chance(e)
	var room := maxf(0.0, 100.0 - empty)
	var scale := 1.0 if total <= room or total == 0.0 else room / total
	var r := randf() * 100.0
	for e in events:
		r -= chance(e) * scale
		if r < 0.0:
			return e
	return null
