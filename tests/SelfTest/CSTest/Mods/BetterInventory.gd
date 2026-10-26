# Self-test for Better Inventory and Equipment (cs_better_inventory). r is the CSTest runner.
extends RefCounted

const BI = preload("res://CSBetterInventory/Mod.gd")
const PATHS := ["res://Items/Medical/Bandage/Bandage.tres", "res://Items/Weapons/AKM/AKM.tres",
	"res://Items/Consumables/Water_Bottle/Water_Bottle.tres", "res://Items/Weapons/AKM/AKM_Magazine.tres"]


func _make(r, interface, grid, path):
	var data = load(path)
	if Engine.get_meta("Cleanstrike").is_loaded("tarkov_looting"):
		load("res://TarkovLooting/TL.gd").learn(data.file)
	var sd := SlotData.new()
	sd.itemData = data
	interface.Create(sd, grid, false)
	await r.wait(0.1)
	var found = null
	for c in grid.get_children():
		if c is Item and c.slotData.itemData == data and not c.is_queued_for_deletion():
			found = c
	return found


func run(r) -> void:
	r.check("BetterInventory: active", BI.active())
	var interface = r.get_node("/root/Map/Core/UI/Interface")
	r.check("BetterInventory: inventory hook installed", "bi_bar" in interface)
	var inv = interface.inventoryGrid
	var made := []
	for p in PATHS:
		made.append(await _make(r, interface, inv, p))
	r.check("BetterInventory: test items in the inventory", not made.has(null))
	if made.has(null):
		return
	var count_before: int = inv.items.size()
	r.check("BetterInventory: sort succeeds", interface.BI_Sort())
	await r.wait(0.1)
	r.check("BetterInventory: nothing lost", inv.items.size() == count_before)
	var akm = made[1]
	var first = null
	for c in inv.items:
		if first == null or c.position.y < first.position.y or (c.position.y == first.position.y and c.position.x < first.position.x):
			first = c
	r.check("BetterInventory: weapons first", first and first.slotData.itemData.type == "Weapon", first.slotData.itemData.name if first else "")
	var overlap := false
	for a in inv.items:
		for b in inv.items:
			if a != b and Rect2(a.position, a.size).grow(-1).intersects(Rect2(b.position, b.size).grow(-1)):
				overlap = true
	r.check("BetterInventory: no overlaps", not overlap)

	interface.BI_Toolbar()
	interface.BI_Filter("bandage")
	r.check("BetterInventory: search fades the rest", made[0].modulate.a == 1.0 and akm.modulate.a < 0.5)
	interface.BI_Filter("")
	r.check("BetterInventory: clearing the search", akm.modulate.a == 1.0)

	var box = await _make(r, interface, interface.containerGrid, "res://Items/Medical/Bandage/Bandage.tres")
	var old = interface.container
	interface.container = interface   # any open container
	var moved: int = interface.BI_QuickStack()
	interface.container = old
	r.check("BetterInventory: quick stack moves matching items", moved >= 1 and made[0].get_parent() == interface.containerGrid)
	for it in made + [box]:
		if it and is_instance_valid(it):
			var g = it.get_parent()
			if g and g.has_method("Pick") and g.items.has(it):
				g.Pick(it)
			it.queue_free()
	interface.bi_bar.queue_free()
	interface.bi_bar = null
	await r.wait(0.1)
