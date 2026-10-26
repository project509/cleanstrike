# Clothes to Rags: rags become a medical item at startup.
extends Node

const CR = preload("res://CSClothesToRags/Mod.gd")


func _ready() -> void:
	CR.apply_rags()


func _exit_tree() -> void:
	CR.release()
