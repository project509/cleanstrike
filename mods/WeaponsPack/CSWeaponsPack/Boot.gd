# CleanStrike Weapons Pack: builds the weapons at startup and lets the game's
# Database find them; lets go of them on quit.
extends Node

const WP = preload("res://CSWeaponsPack/Mod.gd")


func _ready() -> void:
	if not WP.active():
		return
	var db = get_node_or_null("/root/Database")
	if db and not db.has_method("cs_items"):
		db.set_script(load("res://CSWeaponsPack/Database.gd"))
	WP.register.call_deferred()


func _physics_process(_delta: float) -> void:
	var manager = get_node_or_null("/root/Map/Core/Camera/Manager")
	if manager:
		for rig in manager.get_children():
			WP.update_sights(rig)


func _exit_tree() -> void:
	if Engine.has_meta("cs_items"):
		Engine.remove_meta("cs_items")
	WP.unregister()
	WP.release()
