# Better Traders: a new game or a permadeath save wipe resets trader
# reputation and dailies with the rest of your progress.
extends "res://Scripts/Loader.gd"

const BT = preload("res://CSBetterTraders/Mod.gd")


func FormatSave():
	super()
	if BT.active():
		BT.wipe()
