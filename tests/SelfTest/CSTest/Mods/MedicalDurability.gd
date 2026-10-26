# Self-test for Medical Durability (cs_medical_durability). r is the CSTest runner.
extends RefCounted

const MD = preload("res://CSMedicalDurability/Mod.gd")


func run(r) -> void:
	r.check("MedicalDurability: active", MD.active())
	var bandage = load("res://Items/Medical/Bandage/Bandage.tres")
	r.check("MedicalDurability: uses per item", MD.max_uses(bandage) == 3 and MD.max_uses(load("res://Items/Medical/Medkit/Medkit.tres")) == 8)

	# Found supplies are partly used, never empty
	var all_ok := true
	for i in 50:
		var sd := SlotData.new()
		sd.itemData = bandage
		MD.roll_found(sd)
		all_ok = all_ok and MD.uses_left(sd) >= 1 and MD.uses_left(sd) <= 2
	r.check("MedicalDurability: found bandages have 1-2 uses", all_ok)

	# Using one: a use at a time, gone on the last
	var interface = r.get_node("/root/Map/Core/UI/Interface")
	if Engine.get_meta("Cleanstrike").is_loaded("tarkov_looting"):
		load("res://TarkovLooting/TL.gd").learn("Bandage")   # examined, so usable
	var gd = load("res://Resources/GameData.tres")
	var sd := SlotData.new()
	sd.itemData = bandage
	interface.Create(sd, interface.inventoryGrid, false)
	await r.wait(0.2)
	var item = null
	for c in interface.inventoryGrid.get_children():
		if c.slotData.itemData == bandage:
			item = c
	r.check("MedicalDurability: cell shows uses left", item != null and item.condition.visible and item.condition.text == "x3", item.condition.text if item else "")
	if item:
		await interface.Use(item, interface.inventoryGrid)
		r.check("MedicalDurability: one use taken", is_instance_valid(item) and MD.uses_left(item.slotData) == 2 and item.condition.text == "x2")
		await interface.Use(item, interface.inventoryGrid)
		await interface.Use(item, interface.inventoryGrid)
		await r.wait(0.2)
		r.check("MedicalDurability: used up on the last use", not is_instance_valid(item) or item.is_queued_for_deletion())
	gd.isOccupied = false
