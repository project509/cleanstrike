# Loot Highlight: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_loot_highlight"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"mode": "press",      # press (glow for a while), hold, always
	"key": "Z",
	"seconds": 8.0,
	"range": 25.0,
	"pulse": true,
	"in_shelters": false,
}

const COLORS := [Color(0.85, 0.9, 0.85), Color(0.35, 0.6, 1.0), Color(0.95, 0.7, 0.2), Color(0.85, 0.9, 0.85)]

static var pickups: Array = []      # every Pickup in the world
static var lit: Array = []          # meshes glowing now
static var until := 0.0             # press mode: glow ends (seconds)
static var _mats := {}
static var _was_down := false


static func register(p) -> void:
	pickups.append(p)


# One outline material per rarity, shared (pulses together).
static func material(rarity: int) -> StandardMaterial3D:
	if not _mats.has(rarity):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_FRONT
		m.grow = true
		m.grow_amount = 0.012
		m.albedo_color = COLORS[clampi(rarity, 0, COLORS.size() - 1)]
		_mats[rarity] = m
	return _mats[rarity]


static func key_down() -> bool:
	var k := OS.find_keycode_from_string(str(setting("key")))
	return k != KEY_NONE and Input.is_physical_key_pressed(k)


# Should loot glow right now? (called every frame from the player)
static func wanted(now: float, shelter: bool) -> bool:
	if not active() or (shelter and not bool(setting("in_shelters"))):
		return false
	var mode := str(setting("mode"))
	var down := key_down()
	var pressed := down and not _was_down
	_was_down = down
	if mode == "always":
		return true
	if mode == "hold":
		return down
	if pressed:
		until = now + float(setting("seconds"))
	return now < until


static func tick(now: float, from: Vector3, shelter: bool) -> void:
	pickups = pickups.filter(func(p): return is_instance_valid(p) and p.is_inside_tree())
	var on := wanted(now, shelter)
	for m in lit:
		if is_instance_valid(m):
			m.material_overlay = null
	lit = []
	if not on:
		return
	var r := float(setting("range"))
	for p in pickups:
		if p.mesh and p.slotData and p.slotData.itemData and p.global_position.distance_to(from) <= r:
			p.mesh.material_overlay = material(int(p.slotData.itemData.rarity))
			lit.append(p.mesh)
	var a := 0.85
	if bool(setting("pulse")):
		a = 0.45 + 0.4 * (0.5 + 0.5 * sin(now * 4.0))
	for k in _mats:
		_mats[k].albedo_color.a = a

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
