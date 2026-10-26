# No Permadeath: quitting (to the menu or the desktop) away from a shelter
# normally deletes what you carry. With "keep your gear when quitting" on,
# it's saved instead and you continue from your shelter, so no warning.
extends "res://Scripts/Settings.gd"

const M = preload("res://CSNoPermadeath/Mod.gd")


func _on_menu_pressed():
	if NP_KeepsGearOnQuit():
		_np_save_and_exit(false)
		return
	super()


func _on_quit_pressed():
	if NP_KeepsGearOnQuit():
		_np_save_and_exit(true)
		return
	super()


func NP_KeepsGearOnQuit() -> bool:
	return M.active() and bool(M.setting("keep_on_quit")) and not gameData.shelter and not gameData.tutorial and not gameData.isDead


func _np_save_and_exit(quit: bool) -> void:
	Loader.SaveWorld()
	Loader.SaveCharacter()
	M.say("Quit outside a shelter: gear saved.")
	PlayClick()
	blocker.mouse_filter = MOUSE_FILTER_STOP
	if quit:
		Loader.Quit()
	else:
		Loader.LoadScene("Menu")
