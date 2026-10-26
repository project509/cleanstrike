# Self-test for Multi-Use Items (cs_multi_use_items). r is the CSTest runner.
extends RefCounted

const MU = preload("res://CSMultiUseItems/Mod.gd")


func _make(r, interface, path):
	var data = load(path)
	if Engine.get_meta("Cleanstrike").is_loaded("tarkov_looting"):
		load("res://TarkovLooting/TL.gd").learn(data.file)
	var sd := SlotData.new()
	sd.itemData = data
	interface.Create(sd, interface.inventoryGrid, false)
	await r.wait(0.2)
	for c in interface.inventoryGrid.get_children():
		if c is Item and c.slotData.itemData == data and not c.is_queued_for_deletion():
			return c
	return null


func run(r) -> void:
	r.check("MultiUseItems: active", MU.active())
	var water = load("res://Items/Consumables/Water_Bottle/Water_Bottle.tres")
	r.check("MultiUseItems: water bottle has 3 uses", MU.max_uses(water) == 3)
	var bandage = load("res://Items/Medical/Bandage/Bandage.tres")
	var md_on: bool = Engine.get_meta("Cleanstrike").is_loaded("cs_medical_durability")
	r.check("MultiUseItems: medical items left to Medical Durability when it is on", MU.md_owns(bandage) == md_on)
	r.check("MultiUseItems: a sip is a third", is_equal_approx(MU.share(water).hydration, water.hydration / 3.0))

	var interface = r.get_node("/root/Map/Core/UI/Interface")
	var gd = load("res://Resources/GameData.tres")
	var bottle = await _make(r, interface, "res://Items/Consumables/Water_Bottle/Water_Bottle.tres")
	r.check("MultiUseItems: cell shows 3/3", bottle != null and bottle.condition.visible and bottle.condition.text == "3/3", bottle.condition.text if bottle else "")
	if bottle:
		gd.hydration = 10.0
		await interface.Use(bottle, interface.inventoryGrid)
		r.check("MultiUseItems: one sip taken, bottle kept", is_instance_valid(bottle) and MU.uses_left(bottle.slotData) == 2 and bottle.condition.text == "2/3")
		r.check("MultiUseItems: a third of the water", absf(gd.hydration - (10.0 + water.hydration / 3.0)) < 0.5, "%.1f" % gd.hydration)
		bottle.State("Selected")
		interface.DestroyInputItems(RecipeData.new())
		await r.wait(0.1)
		r.check("MultiUseItems: crafting takes one use", is_instance_valid(bottle) and not bottle.is_queued_for_deletion() and MU.uses_left(bottle.slotData) == 1)
		await interface.Use(bottle, interface.inventoryGrid)
		await r.wait(0.2)
		r.check("MultiUseItems: last sip uses it up", not is_instance_valid(bottle) or bottle.is_queued_for_deletion())
		for c in interface.inventoryGrid.get_children():
			if c is Item and water.used.has(c.slotData.itemData):
				c.queue_free()
	gd.isOccupied = false
	await r.wait(0.1)
