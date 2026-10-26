# Better Traders: the refresh hotkey while trading (default F1). A separate
# node so it never competes with other mods' input code on the interface.
extends Node

const M = preload("res://CSBetterTraders/Mod.gd")

var interface


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if interface == null or interface.trader == null or not M.game().isTrading:
		return
	var want := OS.find_keycode_from_string(str(M.setting("refresh_key")))
	if want != KEY_NONE and event.keycode == want:
		interface.BT_Refresh()
		get_viewport().set_input_as_handled()
