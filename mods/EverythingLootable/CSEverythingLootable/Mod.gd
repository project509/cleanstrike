# Everything Lootable: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_everything_lootable"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"amount": 1.0,          # multiplier on how often props hold something
	"registers": true,
	"bookshelves": true,
	"coat_racks": true,
	"vehicles": true,
}

const SHELTERS := ["Attic", "Bunker", "Cabin", "Classroom", "Garage", "Tent"]
const VEHICLE_ITEMS := ["Oil_Filter", "Radiator_Engine", "Jerry_Can", "Toolbox", "Duct_Tape", "Screws",
	"Nails", "Water_Bottle", "Energy_Drink", "Map", "Crackers", "Cigarettes", "Blanket", "Canned_Meat", "Rags"]

# prop scene -> kind: name, setting, items, chance of anything, most items, sound
const PROPS := {
	"res://Assets/Market/Market_Register.tscn": {"name": "Cash Register", "on": "registers", "chance": 0.6, "most": 3, "audio": "Container_Metal",
		"items": ["Cigarettes", "Snus", "Chocolate_War", "Peanuts", "Salty_Liquorice", "Soda_Lemon", "Matches"]},
	"res://Assets/Bookshelf/Bookshelf.tscn": {"name": "Bookshelf", "on": "bookshelves", "chance": 0.25, "most": 1, "audio": "Container_Wood",
		"items": ["Book_Children", "Book_Cooking", "Book_Fishing", "Book_Religion", "Magazine_Crosswords"]},
	"res://Assets/Rack_Coat/Rack_Coat.tscn": {"name": "Coat Rack", "on": "coat_racks", "chance": 0.3, "most": 1, "audio": "Container_Generic",
		"items": ["Gloves_Work", "Beanie_Flame", "Cap_M62", "Tissues", "Cigarettes", "Matches"], "rare": ["Key_Gymnasium", "Key_Tunnel"]},
	"res://Assets/Vehicles/Nissan/Nissan.tscn": {"name": "Car", "on": "vehicles", "chance": 0.5, "most": 2, "audio": "Container_Metal", "items": VEHICLE_ITEMS},
	"res://Assets/Vehicles/Transporter/Transporter.tscn": {"name": "Van", "on": "vehicles", "chance": 0.5, "most": 2, "audio": "Container_Metal", "items": VEHICLE_ITEMS},
	"res://Assets/Vehicles/Tractor/Tractor.tscn": {"name": "Tractor", "on": "vehicles", "chance": 0.4, "most": 1, "audio": "Container_Metal",
		"items": ["Oil_Filter", "Radiator_Engine", "Jerry_Can", "Toolbox", "Duct_Tape", "Rags"]},
	"res://Assets/Vehicles/Volvo/Volvo.tscn": {"name": "Truck", "on": "vehicles", "chance": 0.6, "most": 3, "audio": "Container_Metal",
		"items": ["Oil_Filter", "Radiator_Engine", "Jerry_Can", "Toolbox", "Duct_Tape", "Screws", "Nails",
			"Water_Bottle", "Energy_Drink", "Map", "Crackers", "Cigarettes", "Blanket", "Canned_Meat", "Rags",
			"Sleeping_Bag", "Coffee", "Juice_Orange", "Gloves_Work"]},
}

const LC = preload("res://Scripts/LootContainer.gd")

static var _by_file := {}


static func item(file: String) -> ItemData:
	if _by_file.is_empty():
		for it in load("res://Loot/LT_Master.tres").items:
			if it:
				_by_file[str(it.file)] = it
	return _by_file.get(file)


static func in_shelter(prop: Node) -> bool:
	var n := prop.owner
	while n:
		if str(n.name) in SHELTERS:
			return true
		n = n.owner
	return false


# Give a map prop a container that the player can open.
static func attach(prop: Node3D) -> Node:
	if not is_instance_valid(prop) or not prop.is_inside_tree() or prop.get_node_or_null("CS_Loot"):
		return null
	var kind: Dictionary = PROPS.get(prop.scene_file_path, {})
	if kind.is_empty() or not bool(setting(kind.on)) or in_shelter(prop):
		return null
	var box := AABB()
	var first := true
	for m in prop.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null:
			continue
		var b: AABB = prop.global_transform.affine_inverse() * m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return null
	var c := Node3D.new()
	c.name = "CS_Loot"
	c.set_script(LC)
	c.set("containerName", kind.name)
	c.set("limit", "CS_Nothing")       # the game's own roll finds nothing; we fill it
	var sound := "res://Audio/Interaction/%s.tres" % kind.audio
	if ResourceLoader.exists(sound):
		c.set("audioEvent", load(sound))
	var body := StaticBody3D.new()
	body.name = "StaticBody3D"
	body.collision_layer = 16
	body.collision_mask = 0
	body.add_to_group("Interactable", true)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box.size + Vector3(0.1, 0.1, 0.1)
	shape.shape = bs
	shape.position = box.get_center()
	body.add_child(shape)
	c.add_child(body)
	prop.add_child(c)
	body.owner = c                       # the interactor opens body.owner
	fill(c, kind)
	return c


static func fill(c: Node, kind: Dictionary) -> void:
	if randf() >= clampf(float(kind.chance) * float(setting("amount")), 0.0, 1.0):
		return
	for i in randi_range(1, int(kind.most)):
		var pool: Array = kind.items
		if kind.has("rare") and randf() < 0.04:
			pool = kind.rare
		var d := item(str(pool.pick_random()))
		if d:
			c.CreateLoot(d)
	# Registers: some cash too, with Cash Money
	if kind.on == "registers" and ResourceLoader.exists("res://CSCashMoney/Mod.gd"):
		var cm = load("res://CSCashMoney/Mod.gd")
		if cm.active() and randf() < 0.7:
			c.loot.append(cm.stack(randi_range(5, 80)))

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
