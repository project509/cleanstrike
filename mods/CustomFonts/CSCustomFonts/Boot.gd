# Custom Fonts: swap the font as early as possible, before menus are built.
extends Node

const CF = preload("res://CSCustomFonts/Mod.gd")


func _ready() -> void:
	CF.apply()


func _exit_tree() -> void:
	CF.release()
