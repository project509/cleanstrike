# Loot Highlight: checks the key and lights nearby loot each frame.
extends "res://Scripts/Controller.gd"

const LH = preload("res://CSLootHighlight/Mod.gd")


func _physics_process(delta):
	super(delta)
	LH.tick(Time.get_ticks_msec() / 1000.0, global_position, gameData.shelter)
