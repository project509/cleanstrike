# Fixes Overhaul: picking furniture up into a full catalog deleted it (and
# anything stored inside). Now it stays where it is, with a message.
extends "res://Scripts/Interactor.gd"

const FO = preload("res://CSFixesOverhaul/Mod.gd")


func Interact():
	if FO.on("catalog_full") and gameData.decor and target and target.is_in_group("Furniture") and target.owner:
		for child in target.owner.get_children():
			if child is Furniture and not FO.catalog_room(self, child.itemData):
				Loader.Message("Catalog is full: make room before picking this up", Color.ORANGE)
				return
	super()
