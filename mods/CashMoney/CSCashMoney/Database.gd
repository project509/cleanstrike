# Lets the game's Database find items that mods add (Engine meta "cs_items":
# file name -> pickup scene). Shared by Cleanstrike mods that add items.
extends "res://Scripts/Database.gd"


func cs_items() -> bool:
	return true


func _get(property):
	if Engine.has_meta("cs_items"):
		return Engine.get_meta("cs_items").get(str(property))
	return null
