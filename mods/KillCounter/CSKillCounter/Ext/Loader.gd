# Kill Counter: a new game or a permadeath save wipe starts the count over.
extends "res://Scripts/Loader.gd"

const KC = preload("res://CSKillCounter/Mod.gd")


func FormatSave():
	super()
	if KC.active():
		KC.wipe()
