# Reticles: apply the chosen reticle at startup; U / J cycle it in game.
extends Node

const R = preload("res://CSReticles/Mod.gd")


func _ready() -> void:
	R.apply()


func _unhandled_input(event: InputEvent) -> void:
	if not R.active():
		return
	if R.key_event(event, "style_key"):
		R.cycle("style", R.STYLES)
	elif R.key_event(event, "color_key"):
		R.cycle("color", R.COLORS.keys())


func _exit_tree() -> void:
	R.release()
