# Medical Durability: medical supplies found in containers and on bodies are
# partly used.
extends "res://Scripts/LootContainer.gd"

const MD = preload("res://CSMedicalDurability/Mod.gd")


func CreateLoot(item: ItemData):
	super(item)
	if not loot.is_empty() and loot[-1].itemData == item:
		MD.roll_found(loot[-1])
