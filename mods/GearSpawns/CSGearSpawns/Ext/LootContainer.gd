# Gear Spawns: guns found in containers may have a loaded magazine and
# attachments.
extends "res://Scripts/LootContainer.gd"

const GS = preload("res://CSGearSpawns/Mod.gd")


func CreateLoot(item: ItemData):
	super(item)
	if not loot.is_empty() and loot[-1].itemData == item and not gameData.tutorial:
		GS.kit_found_weapon(loot[-1])
