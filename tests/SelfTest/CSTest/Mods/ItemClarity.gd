# Self-test for Item Clarity (cs_item_clarity). r is the CSTest runner.
extends RefCounted

const IC = preload("res://CSItemClarity/Mod.gd")


func _make(r, interface, data):
	if Engine.get_meta("Cleanstrike").is_loaded("tarkov_looting"):
		load("res://TarkovLooting/TL.gd").learn(data.file)   # examined
	var sd := SlotData.new()
	sd.itemData = data
	interface.Create(sd, interface.inventoryGrid, false)
	await r.wait(0.2)
	for c in interface.inventoryGrid.get_children():
		if c is Item and c.slotData.itemData == data:
			return c
	return null


func run(r) -> void:
	r.check("ItemClarity: active", IC.active())
	IC.refresh_tasks()
	var task_item = null
	for t in load("res://Traders/Generalist/Generalist.tres").tasks:
		if t and not t.deliver.is_empty() and IC.most_needed(t.deliver[0].file) > 0:
			task_item = t.deliver[0]
			break
	r.check("ItemClarity: open tasks found", task_item != null)
	var uses_found := false
	for f in ["Duct_Tape", "Cloth", "Nails", "Screws"]:
		uses_found = uses_found or not IC.uses(f).is_empty()
	r.check("ItemClarity: crafting uses found", uses_found)
	var akm = load("res://Items/Weapons/AKM/AKM.tres")
	r.check("ItemClarity: price tiers rank", IC.tier(akm) >= IC.tier(load("res://Items/Consumables/Can_Empty/Can_Empty.tres")))

	var interface = r.get_node("/root/Map/Core/UI/Interface")
	var made := []
	if task_item:
		var it = await _make(r, interface, task_item)
		made.append(it)
		var mark = it.get_node_or_null("CS_ICTask") if it else null
		r.check("ItemClarity: task marker on the item", mark != null and mark.visible)
		if it:
			interface.tooltip.Update(it)
			var lines := 0
			for c in interface.tooltip.info.get_parent().get_children():
				if c.has_meta("cs_ic") and not c.is_queued_for_deletion() and c.text.begins_with("Task:"):
					lines += 1
			r.check("ItemClarity: tooltip shows the task", lines >= 1)
			interface.tooltip.Reset()
	var gun = await _make(r, interface, akm)
	made.append(gun)
	var partner = null
	for p in akm.compatible:
		if p and p.size.x * p.size.y <= 2:
			partner = p
			break
	if gun and partner:
		made.append(await _make(r, interface, partner))
		interface.IC_Highlight(gun)
		r.check("ItemClarity: hovering a gun lights its parts", interface.ic_lit.size() >= 1)
		interface.IC_Highlight(null)
		await r.wait(0.1)
		r.check("ItemClarity: lights go off", interface.ic_lit.is_empty())
	else:
		r.check("ItemClarity: gun and part made", false)
	for it in made:
		if it and is_instance_valid(it):
			it.queue_free()
	await r.wait(0.1)
