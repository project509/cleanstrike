# CleanStrike Zombies: every shot you fire is heard (recorded at the source).
extends "res://Scripts/WeaponRig.gd"

const ZW = preload("res://CSZombies/Mod.gd")


func FireEvent():
	super()
	if not (data and data.has_meta("cs_silent")):   # silent guns (Weapons Pack's Welrod) are never heard
		ZW.note_shot(gameData.playerPosition)
