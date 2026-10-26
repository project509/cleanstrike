# CleanStrike Zombies: remembers every gunshot (the game flags them only for
# the frames you fire; zombies think four times a second), and lets go of the
# built zombie on quit.
extends Node

const ZM = preload("res://CSZombies/Mod.gd")


var gd = preload("res://Resources/GameData.tres")


func _physics_process(_delta: float) -> void:
	if gd.isFiring and Time.get_ticks_msec() / 1000.0 - ZM.last_shot > 0.15:
		ZM.note_shot(gd.playerPosition)   # a backstop; the weapon reports each shot itself


func _exit_tree() -> void:
	ZM.release()
