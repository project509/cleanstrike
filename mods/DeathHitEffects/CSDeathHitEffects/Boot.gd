# Death and Hit Effects: draws the blood textures at startup, frees them on quit.
extends Node

const DHE = preload("res://CSDeathHitEffects/Mod.gd")


func _ready() -> void:
	# Draw the blood textures now, not on the first hit.
	(func():
		DHE.texture("splat")
		DHE.texture("pool")).call_deferred()


func _exit_tree() -> void:
	DHE.release()
