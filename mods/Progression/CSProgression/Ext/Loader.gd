# Progression: a new game or a permadeath save wipe starts over.
extends "res://Scripts/Loader.gd"

const PG = preload("res://CSProgression/Mod.gd")


func FormatSave():
	super()
	if PG.active():
		PG.wipe()
