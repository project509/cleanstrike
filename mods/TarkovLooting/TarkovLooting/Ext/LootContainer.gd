# Tarkov Looting: containers you haven't finished searching say [Search].
extends "res://Scripts/LootContainer.gd"

const TL = preload("res://TarkovLooting/TL.gd")


func UpdateTooltip():
	super()
	if not locked and TL.should_search(self) and not bool(get_meta("tl_searched", false)):
		gameData.tooltip = containerName + " [Search]"
