# CleanStrike Weapons Pack: lets go of the built rigs on quit.
extends Node

const WP = preload("res://CSWeaponsPack/Mod.gd")


func _exit_tree() -> void:
	WP.release()
