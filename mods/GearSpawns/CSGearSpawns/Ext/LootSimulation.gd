# Gear Spawns: guns lying around may have a loaded magazine and attachments.
extends "res://Scripts/LootSimulation.gd"

const GS = preload("res://CSGearSpawns/Mod.gd")


func SpawnItems():
	var before := get_child_count()
	super()
	for i in range(before, get_child_count()):
		var pickup = get_child(i)
		if "slotData" in pickup and pickup.slotData:
			GS.kit_found_weapon(pickup.slotData)
