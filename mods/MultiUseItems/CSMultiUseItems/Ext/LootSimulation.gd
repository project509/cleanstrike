# Multi-Use Items: multi-use items lying around are partly used too.
extends "res://Scripts/LootSimulation.gd"

const MU = preload("res://CSMultiUseItems/Mod.gd")


func SpawnItems():
	var before := get_child_count()
	super()
	for i in range(before, get_child_count()):
		var pickup = get_child(i)
		if "slotData" in pickup and pickup.slotData:
			MU.roll_found(pickup.slotData)
