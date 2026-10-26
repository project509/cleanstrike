# Cash Money: registers the banknote with the Database at startup.
extends Node

const CM = preload("res://CSCashMoney/Mod.gd")


func _ready() -> void:
	if not CM.active():
		return
	CM.register()
	var db = get_node_or_null("/root/Database")
	if db and not db.has_method("cs_items"):
		db.set_script(load("res://CSCashMoney/Database.gd"))


# Let go of the built item before the engine shuts down.
func _exit_tree() -> void:
	if Engine.has_meta("cs_items"):
		Engine.remove_meta("cs_items")
	CM.release()
