# Medical Durability: medical supplies lying around are partly used too.
extends "res://Scripts/LootSimulation.gd"

const MD = preload("res://CSMedicalDurability/Mod.gd")


func SpawnItems():
	var before := get_child_count()
	super()
	for i in range(before, get_child_count()):
		var pickup = get_child(i)
		if "slotData" in pickup and pickup.slotData:
			MD.roll_found(pickup.slotData)
