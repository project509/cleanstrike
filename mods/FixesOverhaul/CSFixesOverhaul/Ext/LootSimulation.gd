# Fixes Overhaul: floor loot spots with a custom loot table rolled their loot
# but never spawned it, and "forced" ones spawned their first items several
# times over (the list was spawned again after every item added).
extends "res://Scripts/LootSimulation.gd"

const FO = preload("res://CSFixesOverhaul/Mod.gd")


func _ready():
	if not FO.on("floor_loot"):
		super()
		return
	if get_child_count() > 0:
		get_child(0).queue_free()
	if not custom:
		ClearBuckets()
		FillBuckets()
		GenerateLoot()
	elif not force:
		ClearBuckets()
		FillBucketsCustom()
		GenerateLoot()
	else:
		for item in custom.items:
			loot.append(item)
	SpawnItems()
