# Save Anywhere: Continue from the menu goes to where you quit, not your
# shelter (once). Dying drops the saved spot.
extends "res://Scripts/Loader.gd"

const SA = preload("res://CSSaveAnywhere/Mod.gd")


func LoadScene(scene: String):
	if SA.active():
		if scene == "Death":
			SA.clear()
		elif gameData.menu and scene != "Menu" and scene == ValidateShelter():
			var s := SA.read()
			if not s.is_empty():
				SA.pending = s
				scene = str(s.map)
	return await super(scene)
