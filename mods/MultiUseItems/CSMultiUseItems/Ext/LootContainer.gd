# Multi-Use Items: multi-use items found in containers and on bodies are
# partly used.
extends "res://Scripts/LootContainer.gd"

const MU = preload("res://CSMultiUseItems/Mod.gd")


func CreateLoot(item: ItemData):
	super(item)
	if not loot.is_empty() and loot[-1].itemData == item:
		MU.roll_found(loot[-1])
