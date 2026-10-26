# CleanStrike Fixes Overhaul: shared helpers. Each fix has its own switch.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_fixes_overhaul"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"doors": true,
	"overlapping_areas": true,
	"event_odds": true,
	"event_empty": 20.0,
	"ai_night_fog": true,
	"catalog_full": true,
	"decor_cancel": true,
	"tooltips": true,
	"trader_info": true,
	"floor_loot": true,
	"empty_marker": true,
	"unstuck": true,
	"unstuck_key": "F9",
	"trader_shadows": false,
}

# Self-test hooks: values here win over the player's settings.
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


# Is this fix switched on?
static func on(key: String) -> bool:
	return active() and bool(setting(key))


static func say(text: String) -> void:
	var c := cs()
	if c:
		c.log_message(MOD_ID, text)
	else:
		print("[%s] %s" % [MOD_ID, text])


# ---------------------------------------------------------------- doors

# Which way a hinged door should open (+1/-1 for openAngle.y) so it swings
# away from someone standing at `from`. 0 if it can't tell (then the game's
# own direction is kept). Works in the door's own (closed) frame: the panel
# runs along local x from the hinge, and turning by +angle about y moves its
# free edge toward local -z when the panel runs along +x.
static func door_away_sign(door: Node3D, from: Vector3) -> int:
	var panel := door_panel_center(door)
	if absf(panel.x) < 0.05:
		return 0
	var player := door.to_local(from)
	var side := signf(player.z - panel.z)
	if side == 0.0:
		return 0
	return int(side * signf(panel.x))


# Centre of the door's visible panel, in the door's local space.
static func door_panel_center(door: Node3D) -> Vector3:
	var inv := door.global_transform.affine_inverse()
	var total := Vector3.ZERO
	var count := 0
	for n in door.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		if m.mesh == null:
			continue
		total += inv * (m.global_transform * m.get_aabb().get_center())
		count += 1
	return total / count if count > 0 else Vector3.ZERO


# ---------------------------------------------------------------- catalog

# Room in the furniture catalog for this item (either way round)?
static func catalog_room(from: Node, item_data) -> bool:
	var interface = from.get_tree().current_scene.get_node_or_null("/root/Map/Core/UI/Interface")
	if interface == null or not interface.has_method("FO_CatalogHasRoom"):
		return true
	return interface.FO_CatalogHasRoom(item_data)


# ---------------------------------------------------------------- areas

# Every kind of area you're standing in counts, not just the last one the
# game happened to check.
static func area_flags(types: Array) -> Dictionary:
	return {
		"indoor": "Indoor" in types,
		"isBurning": "Fire" in types,
		"isPoisoning": "Poison" in types,
		"isRazor": "Razor" in types,
		"heat": "Heat" in types,
		"PRX_Heat": "PRX_Heat" in types,
		"PRX_Workbench": "PRX_Workbench" in types,
	}


# ---------------------------------------------------------------- AI sight

# How far AI can see: fog and night both limit it, the tighter one wins
# (the game let fog's 100 m beat night's 40 m on foggy nights).
static func sight_distance(fog: bool, night: bool) -> float:
	var d := 150.0
	if fog:
		d = minf(d, 100.0)
	if night:
		d = minf(d, 40.0)
	return d


# ---------------------------------------------------------------- events

# One roll over every eligible event: each takes its own chance-sized slice
# of 0-100 and the rest is "nothing", so stated chances are the real ones.
# If they add up past (100 - empty), they're scaled to leave `empty` % quiet.
static func fair_pick(events: Array, empty := 20.0):
	var total := 0.0
	for e in events:
		total += float(e.possibility)
	var room := maxf(0.0, 100.0 - empty)
	var scale := 1.0 if total <= room or total == 0.0 else room / total
	var r := randf() * 100.0
	for e in events:
		r -= float(e.possibility) * scale
		if r < 0.0:
			return e
	return null
