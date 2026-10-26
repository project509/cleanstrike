# Sandbox Mode: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_sandbox_mode"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"menu_key": "F6",
}

const WEATHERS := ["Neutral", "Overcast", "Wind", "Rain", "Storm", "Aurora"]

# Cheat switches for this session; all start off.
static var state := {}


static func on(key: String) -> bool:
	return bool(state.get(key, false))


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _sim() -> Node:
	return _tree().root.get_node_or_null("Simulation")


static func find_items(text: String) -> Array:
	text = text.strip_edges().to_lower()
	var out := []
	var seen := {}
	var pool: Array = load("res://Loot/LT_Master.tres").items.duplicate()
	for it in pool:
		if it == null or seen.has(it.file) or str(it.type) == "Furniture":
			continue
		if text == "" or text in str(it.name).to_lower() or text in str(it.type).to_lower():
			seen[it.file] = true
			out.append(it)
	out.sort_custom(func(a, b): return str(a.name) < str(b.name))
	return out


# Put one in the inventory (full stack / full magazine), or at your feet.
static func spawn(data: ItemData) -> bool:
	var ui = _tree().root.get_node_or_null("Map/Core/UI/Interface")
	if ui == null:
		return false
	var sd := SlotData.new()
	sd.itemData = data
	if data.defaultAmount > 0:
		sd.amount = data.defaultAmount
	if ResourceLoader.exists("res://TarkovLooting/TL.gd"):
		var tl = load("res://TarkovLooting/TL.gd")
		if tl.active():
			tl.learn(data.file)        # spawned items come examined
	ui.Create(sd, ui.inventoryGrid, true)
	return true


static func add_hours(h: int) -> void:
	var sim := _sim()
	if sim:
		sim.time = fmod(sim.time + h * 100.0, 2400.0)


static func set_time(t: float) -> void:
	var sim := _sim()
	if sim:
		sim.time = t


static func next_weather() -> void:
	var sim := _sim()
	if sim:
		sim.weather = WEATHERS[(WEATHERS.find(str(sim.weather)) + 1) % WEATHERS.size()]
		sim.weatherTime = 600.0


static func switch_season() -> void:
	var sim := _sim()
	if sim:
		sim.season = 2 if sim.season == 1 else 1


static func restock() -> int:
	var n := 0
	for t in _tree().current_scene.find_children("*", "Node3D", true, false):
		if t is Trader:
			t.CreateSupply()
			n += 1
	return n


static func kill_all() -> int:
	var n := 0
	for id in _tree().get_nodes_in_group("AI"):
		var ai = id.owner
		if ai and "dead" in ai and not ai.dead and ai.get("active"):
			ai.Death(Vector3.UP, 1.0)
			n += 1
	return n

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
