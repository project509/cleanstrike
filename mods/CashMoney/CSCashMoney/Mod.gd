# Cash Money: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_cash_money"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"markup": 20.0,          # % worse than bartering, both ways
	"container_chance": 8.0, # % of civilian/military containers with cash
	"trader_cash": true,     # traders carry cash you can sell for
	"show_total": true,
}

const FILE := "CS_Euro"
const DIR := "res://CSCashMoney/Files/"

static var _data: ItemData


static func _texture(name: String) -> ImageTexture:
	var img := Image.load_from_file(DIR + name)
	return ImageTexture.create_from_image(img) if img else null


# The banknote item, built once. Saves embed it, so they still load
# without the mod.
static func euro() -> ItemData:
	if _data:
		return _data
	var d := ItemData.new()
	d.file = FILE
	d.name = "Euro"
	d.inventory = "Euro"
	d.rotated = "Euro"
	d.equipment = "Euro"
	d.display = "EUR"
	d.type = "Misc"
	d.subtype = "Cash"
	d.weight = 0.001
	d.value = 1
	d.size = Vector2(1, 1)
	d.icon = _texture("Icon_Euro.png")
	d.showAmount = true
	d.stackable = true
	d.defaultAmount = 50
	d.maxAmount = 100000
	d.rarity = d.Rarity.Null      # never rolled by the game's own tables
	var sprite := Sprite2D.new()
	sprite.name = "Euro"
	sprite.texture = d.icon
	sprite.position = Vector2(32, 32)
	sprite.scale = Vector2(0.5, 0.5)
	if ResourceLoader.exists("res://UI/Effects/MT_Item.tres"):
		sprite.material = load("res://UI/Effects/MT_Item.tres")
	d.tetris = PackedScene.new()
	d.tetris.pack(sprite)
	sprite.free()
	_data = d
	return d


# The bundle lying in the world (what dropping it makes).
static var _pickup: PackedScene
static func pickup_scene() -> PackedScene:
	if _pickup:
		return _pickup
	var body := RigidBody3D.new()
	body.name = "Euro"
	body.collision_layer = 4
	body.collision_mask = 29
	if ResourceLoader.exists("res://Items/Physics/Item_Physics.tres"):
		body.physics_material_override = load("res://Items/Physics/Item_Physics.tres")
	body.add_to_group("Item", true)
	body.set_script(load("res://Scripts/Pickup.gd"))
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.layers = 4
	mesh.visibility_range_end = 25.0
	var box := BoxMesh.new()
	box.size = Vector3(0.155, 0.02, 0.08)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _texture("TX_Euro.png")
	mat.roughness = 0.9
	box.material = mat
	mesh.mesh = box
	body.add_child(mesh)
	mesh.owner = body
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	body.add_child(col)
	col.owner = body
	var sd := SlotData.new()
	sd.itemData = euro()
	sd.amount = euro().defaultAmount
	body.set("slotData", sd)
	body.set("mesh", mesh)
	body.set("collision", col)
	_pickup = PackedScene.new()
	_pickup.pack(body)
	body.free()
	return _pickup


static func is_cash(data) -> bool:
	return data != null and str(data.file) == FILE


static func stack(amount: int) -> SlotData:
	var sd := SlotData.new()
	sd.itemData = euro()
	sd.amount = maxi(1, amount)
	return sd


static func rate() -> float:
	return 1.0 + float(setting("markup")) / 100.0


# Everything the game asks the Database for by file name.
static func register() -> void:
	var reg: Dictionary = Engine.get_meta("cs_items") if Engine.has_meta("cs_items") else {}
	reg[FILE] = pickup_scene()
	Engine.set_meta("cs_items", reg)

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


static func release() -> void:
	_pickup = null
	_data = null
