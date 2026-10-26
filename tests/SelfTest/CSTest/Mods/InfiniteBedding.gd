# Self-test for Infinite Bedding (cs_infinite_bedding). r is the CSTest runner.
extends RefCounted

const IB = preload("res://CSInfiniteBedding/Mod.gd")


func run(r) -> void:
	r.check("InfiniteBedding: active", IB.active())
	var interface = r.get_node("/root/Map/Core/UI/Interface")
	var ui = r.get_node("/root/Map/Core/UI")
	var gd = load("res://Resources/GameData.tres")
	var sd := SlotData.new()
	sd.itemData = load("res://Items/Misc/Pillow/Pillow.tres")
	ui.ToggleInterface()
	await r.wait(0.3)
	interface.Create(sd, interface.inventoryGrid, false)
	await r.wait(0.2)
	var pillow = null
	for c in interface.inventoryGrid.get_children():
		if c.slotData.itemData.file == "Pillow":
			pillow = c
	r.check("InfiniteBedding: a pillow to sleep on", pillow != null)
	if pillow == null:
		return
	r.check("InfiniteBedding: pillow is kept", IB.keeps(pillow))
	interface.contextItem = pillow
	interface.contextGrid = interface.inventoryGrid
	var simulate: bool = r.get_node("/root/Simulation").simulate
	interface.ContextSleep()
	await r.wait(0.3)
	r.check("InfiniteBedding: still there after sleeping", is_instance_valid(pillow) and not pillow.is_queued_for_deletion() and gd.isSleeping)
	# Wake straight away for the other tests
	while gd.isSleeping:
		await r.wait(0.5)
	interface.inventoryGrid.Pick(pillow)
	pillow.queue_free()
	r.get_node("/root/Simulation").simulate = simulate
