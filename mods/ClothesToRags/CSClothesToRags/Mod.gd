# Clothes to Rags: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_clothes_to_rags"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"yield": 1.0,            # multiplier on rags per item
	"leather": false,        # leather can be torn
	"boots": false,          # boots can be torn
	"rag_health": 2.0,
	"rag_bleeding": true,
	"rag_small": true,       # rags take one slot
	"blacklist": "",         # item names, comma separated
}

const RAGS := "res://Items/Misc/Rags/Rags.tres"
const BANDAGE := "res://Items/Medical/Bandage/Bandage.tres"

static var _orig := {}


static func rags() -> ItemData:
	return load(RAGS)


# Rags become a basic medical item (undone when the mod is off).
static func apply_rags() -> void:
	var r := rags()
	if _orig.is_empty():
		_orig = {"usable": r.usable, "phrase": r.phrase, "audio": r.audio, "health": r.health,
			"bleeding": r.bleeding, "size": r.size, "tetris": r.tetris}
	if not active():
		for k in _orig:
			r.set(k, _orig[k])
		return
	r.usable = true
	r.phrase = "Heal"
	r.audio = load(BANDAGE).audio
	r.health = float(setting("rag_health"))
	r.bleeding = bool(setting("rag_bleeding"))
	if bool(setting("rag_small")):
		r.size = Vector2(1, 1)
		r.tetris = _small_tetris(r)
	else:
		r.size = _orig.size
		r.tetris = _orig.tetris


static var _small: PackedScene
static func _small_tetris(r: ItemData) -> PackedScene:
	if _small == null:
		var s := Sprite2D.new()
		s.name = "Rags"
		s.texture = r.icon
		s.position = Vector2(32, 32)
		s.scale = Vector2(0.25, 0.25)
		if ResourceLoader.exists("res://UI/Effects/MT_Item.tres"):
			s.material = load("res://UI/Effects/MT_Item.tres")
		_small = PackedScene.new()
		_small.pack(s)
		s.free()
	return _small


static func release() -> void:
	if not _orig.is_empty():
		for k in _orig:
			rags().set(k, _orig[k])
	_small = null


# How many rags an item gives (0 = it can't be torn).
static func yield_of(data: ItemData) -> int:
	if not active() or data == null or data.type != "Clothing" or data.slots.is_empty():
		return 0
	for n in str(setting("blacklist")).split(",", false):
		if n.strip_edges().to_lower() == data.name.to_lower():
			return 0
	if "leather" in data.name.to_lower() and not bool(setting("leather")):
		return 0
	var slot: String = data.slots[0]
	if slot == "Feet" and not bool(setting("boots")):
		return 0
	var base := 1
	match slot:
		"Torso": base = randi_range(2, 3)
		"Legs": base = randi_range(1, 2)
	return maxi(1, int(round(base * float(setting("yield")))))


# Tear the item into rags in the same grid.
static func tear(interface, item, grid) -> int:
	var n := yield_of(item.slotData.itemData)
	if n == 0 or grid == null:
		return 0
	grid.Pick(item)
	item.queue_free()
	for i in n:
		var sd := SlotData.new()
		sd.itemData = rags()
		interface.Create(sd, grid, true)
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
