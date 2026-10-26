# Kill Counter: your kills in the character panel (in the empty "?" slot).
extends "res://Scripts/Interface.gd"

const KC = preload("res://CSKillCounter/Mod.gd")

var kc_cell: Control


func Open():
	super()
	if not KC.active() or not bool(KC.setting("panel")):
		return
	var row = characterUI.get_node_or_null("Stats/Elements")
	if row == null:
		return
	if kc_cell == null or not is_instance_valid(kc_cell):
		var blank = row.get_node_or_null("?")
		kc_cell = row.get_node("Tasks").duplicate()
		kc_cell.name = "KC_Kills"
		row.add_child(kc_cell)
		if blank:
			row.move_child(kc_cell, blank.get_index())
			blank.hide()
		kc_cell.get_node("Header").text = "Kills"
	var value: Label = kc_cell.get_node("Value")
	value.text = "%02d" % KC.total()
	var lines := []
	for k in KC.tally():
		lines.append("%s: %d" % [k, int(KC.tally()[k])])
	kc_cell.tooltip_text = "\n".join(lines)
