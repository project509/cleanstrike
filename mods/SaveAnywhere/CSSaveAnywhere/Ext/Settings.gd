# Save Anywhere: quitting (to the menu or the desktop) away from a shelter
# saves your gear and your exact spot, with no warning.
extends "res://Scripts/Settings.gd"

const SA = preload("res://CSSaveAnywhere/Mod.gd")


func _on_menu_pressed():
	if SA_CanSuspend():
		SA_Suspend(false)
		return
	super()


func _on_quit_pressed():
	if SA_CanSuspend():
		SA_Suspend(true)
		return
	super()


func SA_CanSuspend() -> bool:
	return SA.active() and not gameData.shelter and not gameData.tutorial and not gameData.isDead


func SA_Suspend(quit: bool) -> void:
	var map = get_tree().current_scene.get_node_or_null("/root/Map")
	var controller = get_tree().current_scene.get_node_or_null("/root/Map/Core/Controller")
	if map == null or controller == null:
		super._on_quit_pressed() if quit else super._on_menu_pressed()
		return
	Loader.SaveWorld()
	Loader.SaveCharacter()
	SA.write(map.mapName, controller.global_position, controller.global_rotation.y)
	PlayClick()
	blocker.mouse_filter = MOUSE_FILTER_STOP
	if quit:
		Loader.Quit()
	else:
		Loader.LoadScene("Menu")
