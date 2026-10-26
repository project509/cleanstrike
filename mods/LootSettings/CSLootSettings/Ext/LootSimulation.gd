# Loot Settings: loose loot on the floor rolls with the chosen preset too.
extends "res://Scripts/LootSimulation.gd"

const LS = preload("res://CSLootSettings/Mod.gd")


func GenerateLoot():
	if not LS.changes_loot():
		super()
		return
	for item in LS.roll(LS.weighted(commonBucket), LS.weighted(rareBucket), legendaryBucket, joker, false):
		if item:
			loot.append(item)
