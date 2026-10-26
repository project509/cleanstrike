# Hideout Lights: builds the light fixtures at startup (item data, inventory
# sprite and the placeable scene), registers them with the game's Database
# and puts them in the traders' stock.
extends Node

const HL = preload("res://CSHideoutLights/Mod.gd")

signal built


func _ready() -> void:
	if not HL.active():
		return
	var db = get_node_or_null("/root/Database")
	if db and not db.has_method("cs_items"):
		db.set_script(load("res://CSHideoutLights/Database.gd"))
	_build_all.call_deferred()


func _build_all() -> void:
	var master = load("res://Loot/LT_Master.tres")
	for file in HL.FIXTURES:
		var data := _item(file)
		HL.items[file] = data
		HL.scenes[file] = await _scene(file, data)
		var reg: Dictionary = Engine.get_meta("cs_items") if Engine.has_meta("cs_items") else {}
		reg[file] = HL.scenes[file]
		Engine.set_meta("cs_items", reg)
		if not master.items.has(data):
			master.items.append(data)
	built.emit()


func _item(file: String) -> ItemData:
	var spec: Array = HL.FIXTURES[file]
	var d := ItemData.new()
	d.file = file
	d.name = spec[0]
	d.inventory = spec[0]
	d.rotated = spec[0]
	d.equipment = spec[0]
	d.display = spec[0]
	d.type = "Furniture"
	d.value = int(round(spec[8] * float(HL.setting("price"))))
	d.rarity = d.Rarity.Null          # traders only, never random loot
	d.size = spec[2]
	var img := Image.load_from_file(HL.DIR + "Icon_%s.png" % spec[1].get_file().get_basename())
	d.icon = ImageTexture.create_from_image(img) if img else null
	for t in spec[9]:
		d.set(t, true)
	var sprite := Sprite2D.new()
	sprite.name = file
	sprite.texture = d.icon
	sprite.position = Vector2(32, 32) * spec[2]
	sprite.scale = Vector2(0.5, 0.5)
	if ResourceLoader.exists("res://UI/Effects/MT_Item.tres"):
		sprite.material = load("res://UI/Effects/MT_Item.tres")
	d.tetris = PackedScene.new()
	d.tetris.pack(sprite)
	sprite.free()
	return d


# The placeable fixture: the game's own furniture scene with the lamp in it,
# measured by the game's own furniture initializer.
func _scene(file: String, data: ItemData) -> PackedScene:
	var spec: Array = HL.FIXTURES[file]
	var root: Node3D = load(HL.BASE_F).instantiate()
	root.name = file + "_F"
	var visual: Node3D = load(spec[1]).instantiate()
	visual.name = "Visual"
	root.add_child(visual)
	for body in visual.find_children("*", "CollisionObject3D", true, false):
		body.collision_layer = 0
		body.collision_mask = 0
	# Bounds of the lamp, then sit it on the floor (or flat against the wall)
	var box := _bounds(visual)
	if spec[3]:                                   # wall pieces: thin side to the wall
		if box.size.y < box.size.x and box.size.y < box.size.z:
			visual.rotation.x = -PI / 2.0         # ceiling lights: lit face (down) turned outwards
		elif box.size.x < box.size.z:
			visual.rotation.y = PI / 2.0
		box = _bounds(visual)
	visual.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z if not spec[3] else box.position.z)
	box = _bounds(visual)
	# The furniture parts measure a clear box of the lamp's size
	var mesh: MeshInstance3D = root.get_node("Mesh")
	var bm := BoxMesh.new()
	bm.size = box.size
	var clear := StandardMaterial3D.new()
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.albedo_color = Color(1, 1, 1, 0)
	mesh.mesh = bm
	mesh.position = box.get_center()
	mesh.set_surface_override_material(0, clear)
	for n in ["Collider_R", "Collider_P"]:
		var c: MeshInstance3D = root.get_node(n)
		c.mesh = bm
		c.position = box.get_center()
		var shape := BoxShape3D.new()
		shape.size = box.size
		c.get_child(0).get_child(0).shape = shape
	root.get_node("Collider_R").get_child(0).add_to_group("Interactable", true)   # Use toggles it
	for lod in root.find_children("LOD*", "MeshInstance3D", false, false):
		lod.queue_free()
	# Its light
	if spec[4] != "own":
		var light := OmniLight3D.new()
		light.name = "CS_Light"
		light.light_color = spec[5]
		light.light_energy = float(spec[6]) * float(HL.setting("brightness"))
		light.omni_range = spec[7]
		light.shadow_enabled = bool(HL.setting("shadows"))
		root.add_child(light)
		light.position = Vector3(0, box.end.y - 0.12, 0) if not spec[3] else box.get_center() + Vector3(0, 0, box.size.z / 2.0 + 0.15)
	root.set_script(load("res://CSHideoutLights/Fixture.gd"))
	root.set_meta("cs_label", spec[0])
	var furniture = root.get_node("Furniture")
	furniture.itemData = data
	furniture.wallElement = spec[3]
	# Measure with the game's initializer (it needs the tree), then pack
	add_child(root)
	root.position = Vector3(0, -1000, 0)
	furniture.initialize = true
	await get_tree().process_frame
	remove_child(root)
	root.position = Vector3.ZERO
	for n in root.find_children("*", "", true, false):
		if n.owner == null and not n.is_queued_for_deletion():
			n.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


# Bounds of a lamp in its parent's space (works outside the tree).
func _bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m in [n] + n.find_children("*", "MeshInstance3D", true, false):
		if m is MeshInstance3D and m.mesh and m.layers != 0:
			var b: AABB = _rel(m, n.get_parent()) * m.get_aabb()
			box = b if first else box.merge(b)
			first = false
	return box


func _rel(node: Node3D, top: Node) -> Transform3D:
	var t := Transform3D()
	var x: Node = node
	while x and x != top:
		if x is Node3D:
			t = x.transform * t
		x = x.get_parent()
	return t


func _exit_tree() -> void:
	if Engine.has_meta("cs_items"):
		Engine.remove_meta("cs_items")
	HL.items.clear()
	HL.scenes.clear()
