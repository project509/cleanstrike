# Progression: Scavenger finds a little extra in containers.
extends "res://Scripts/LootContainer.gd"

const PG = preload("res://CSProgression/Mod.gd")


func _ready():
	super()
	if PG.active() and custom.is_empty() and not locked and not furniture and randf() < PG.bonus("scavenger"):
		var pool: Array = commonBucket if not commonBucket.is_empty() else rareBucket
		if not pool.is_empty():
			CreateLoot(pool.pick_random())
