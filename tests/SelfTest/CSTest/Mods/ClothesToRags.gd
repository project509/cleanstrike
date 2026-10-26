# Self-test for Clothes to Rags (cs_clothes_to_rags). r is the CSTest runner.
extends RefCounted

const CR = preload("res://CSClothesToRags/Mod.gd")


func _make(r, interface, path):
	var data = load(path)
	if Engine.get_meta("Cleanstrike").is_loaded("tarkov_looting"):
		load("res://TarkovLooting/TL.gd").learn(data.file)
	var sd := SlotData.new()
	sd.itemData = data
	interface.Create(sd, interface.inventoryGrid, false)
	await r.wait(0.2)
	for c in interface.inventoryGrid.get_children():
		if c is Item and c.slotData.itemData == data:
			return c
	return null


func _rags(interface) -> Array:
	return interface.inventoryGrid.get_children().filter(func(c): return c is Item and c.slotData.itemData == CR.rags())


func run(r) -> void:
	r.check("ClothesToRags: active", CR.active())
	var rags := CR.rags()
	r.check("ClothesToRags: rags are medical, one slot", rags.usable and rags.bleeding and rags.size == Vector2(1, 1))
	r.check("ClothesToRags: boots and leather stay whole", CR.yield_of(load("res://Items/Clothing/Boots_Combat/Boots_Combat.tres")) == 0 \
		and CR.yield_of(load("res://Items/Clothing/Gloves_Leather/Gloves_Leather.tres")) == 0)
	r.check("ClothesToRags: guns can't be torn", CR.yield_of(load("res://Items/Weapons/AKM/AKM.tres")) == 0)

	var interface = r.get_node("/root/Map/Core/UI/Interface")
	for old in _rags(interface):
		old.queue_free()
	await r.wait(0.1)
	var hoodie = await _make(r, interface, "res://Items/Clothing/Hoodie_Gray/Hoodie_Gray.tres")
	r.check("ClothesToRags: hoodie in the inventory", hoodie != null)
	if hoodie:
		interface.contextItem = hoodie
		interface.contextGrid = interface.inventoryGrid
		var ctx = null
		for n in interface.find_children("*", "Control", true, false):
			if n.has_method("_cr_on_tear"):
				ctx = n
		if ctx:
			ctx.Update(hoodie.slotData)
		r.check("ClothesToRags: menu offers Tear into rags", ctx != null and ctx.cr_tear.visible)
		CR.tear(interface, hoodie, interface.inventoryGrid)   # what the button does (inventory open)
		await r.wait(0.3)
		var n := _rags(interface).size()
		r.check("ClothesToRags: a top gives 2-3 rags", n >= 2 and n <= 3, str(n))
		r.check("ClothesToRags: the hoodie is gone", not is_instance_valid(hoodie) or hoodie.is_queued_for_deletion())
	var gd = load("res://Resources/GameData.tres")
	var character = r.get_node("/root/Map/Core/Controller/Character") if r.has_node("/root/Map/Core/Controller/Character") else interface.character
	gd.bleeding = true
	character.Consume(rags)
	r.check("ClothesToRags: a rag stops bleeding", not gd.bleeding)
	for c in _rags(interface):
		c.queue_free()
	await r.wait(0.1)
