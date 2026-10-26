# Fixes Overhaul: a container you've emptied says so ("[Empty]"), instead of
# looking the same as one you haven't opened.
extends "res://Scripts/LootContainer.gd"

const FO = preload("res://CSFixesOverhaul/Mod.gd")


func UpdateTooltip():
	super()
	if FO.on("empty_marker") and storaged and storage.is_empty() and not locked:
		gameData.tooltip = containerName + " [Empty]"
