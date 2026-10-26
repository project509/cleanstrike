# Gear Spawns: enemies with a flashlight or night vision see farther at night.
extends "res://Scripts/Sensor.gd"

const GS = preload("res://CSGearSpawns/Mod.gd")


func Visibility(delta):
	super(delta)
	if GS.active() and boostTimer <= 0.0 and gameData.TOD == 4 and has_meta("gs_boost"):
		viewDistance += float(get_meta("gs_boost"))
