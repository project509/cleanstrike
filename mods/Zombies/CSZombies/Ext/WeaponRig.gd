# CleanStrike Zombies: every shot you fire is heard (recorded at the source).
extends "res://Scripts/WeaponRig.gd"

const ZW = preload("res://CSZombies/Mod.gd")


func FireEvent():
	super()
	ZW.note_shot(gameData.playerPosition)
