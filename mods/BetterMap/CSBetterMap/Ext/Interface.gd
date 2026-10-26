# Better Map: the overlay goes on whenever the map is shown.
extends "res://Scripts/Interface.gd"

const BM = preload("res://CSBetterMap/Mod.gd")


func FocusMap():
	BM.show_on(mapScroll.map)
	super()
