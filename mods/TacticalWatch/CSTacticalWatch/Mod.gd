# Tactical Watch: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_tactical_watch"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"key": "Y",
	"mode": "toggle",        # toggle, hold
	"needs_watch": true,     # the panel only works with the watch on
	"exits": true,
	"kills": true,
	"enemies": true,
	"loot": true,            # watch found in civilian loot and sold by the Gunsmith
	"scale": 1.0,
}

const WATCH := "Watch_Tactical"
const TIME_SLOT := 18
const GREEN := Color(0.6, 0.95, 0.65)
const DIM := Color(0.8, 0.85, 0.82, 0.85)
const DIRS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

static var shown := false
static var ai: Array = []        # living enemies register here
static var _loot_done := false


static func key_event(event: InputEvent) -> bool:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	var k := OS.find_keycode_from_string(str(setting("key")))
	return k != KEY_NONE and event.physical_keycode == k


static func wearing() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var ui = tree.root.get_node_or_null("Map/Core/UI/Interface") if tree else null
	if ui == null:
		return false
	var slot = ui.equipmentUI.get_child(TIME_SLOT)
	return slot.get_child_count() > 0 and str(slot.get_child(0).slotData.itemData.file) == WATCH


static func visible_now() -> bool:
	if not active():
		return false
	if bool(setting("needs_watch")) and not wearing():
		return false
	if str(setting("mode")) == "hold":
		var k := OS.find_keycode_from_string(str(setting("key")))
		return k != KEY_NONE and Input.is_physical_key_pressed(k)
	return shown


static func compass(deg: float) -> String:
	return DIRS[int(round(fposmod(deg, 360.0) / 45.0)) % 8]


static func bearing(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return fposmod(rad_to_deg(atan2(d.x, -d.z)), 360.0)


# The watch shows: [text, colour] lines.
static func panel_lines(node: Node) -> Array:
	var tree := node.get_tree()
	var sim = tree.root.get_node_or_null("Simulation")
	var out := []
	if sim:
		var t := int(sim.time)
		out.append(["%s  %02d:%02d" % [str(sim.Weekday()).left(3).to_upper(), (t / 100) % 24, t % 100], GREEN])
		out.append(["Day %d" % int(sim.day), DIM])
	var m = tree.root.get_node_or_null("Map")
	if m and "mapName" in m:
		out.append([str(m.mapName) + ("" if m.mapType in ["Shelter", m.mapName] else "  (%s)" % m.mapType), DIM])
	var cam := node.get_viewport().get_camera_3d()
	if cam:
		var f := -cam.global_transform.basis.z
		var hdg := fposmod(rad_to_deg(atan2(f.x, -f.z)), 360.0)
		out.append(["Heading %03d  %s" % [int(round(hdg)) % 360, compass(hdg)], DIM])
		if bool(setting("exits")):
			var best = null
			var best_d := INF
			for body in tree.get_nodes_in_group("Transition"):
				var tr = body.owner if body.owner else body
				if tr is Node3D:
					var dist: float = tr.global_position.distance_to(cam.global_position)
					if dist < best_d:
						best_d = dist
						best = tr
			if best:
				var name: String = str(best.get("nextMap")) if best.get("nextMap") else "Exit"
				out.append(["Exit: %s  %s %d m" % [name, compass(bearing(cam.global_position, best.global_position)), int(best_d)], DIM])
	if bool(setting("kills")) and ResourceLoader.exists("res://CSKillCounter/Mod.gd"):
		var kc = load("res://CSKillCounter/Mod.gd")
		if kc.active():
			out.append(["Kills: %d" % kc.total(), DIM])
	if bool(setting("enemies")):
		ai = ai.filter(func(a): return is_instance_valid(a) and a.is_inside_tree() and not a.dead)
		out.append(["Hostiles in area: %d" % ai.size(), DIM])
	return out


# The watch turns up in civilian loot and at the Gunsmith (runtime only).
static func apply_loot() -> void:
	if _loot_done or not active() or not bool(setting("loot")):
		return
	_loot_done = true
	var w = load("res://Items/Electronics/Watch_Tactical/Watch_Tactical.tres")
	w.civilian = true
	w.gunsmith = true

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
