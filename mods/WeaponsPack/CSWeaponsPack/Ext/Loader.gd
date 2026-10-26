# CleanStrike Weapons Pack: the start kit. With "Start new games with the
# pack's guns" on, a new game's first character load gets every pack gun
# (loaded) and a box of each of their ammo.
extends "res://Scripts/Loader.gd"

const WPK = preload("res://CSWeaponsPack/Mod.gd")


func NewGame(difficulty, season):
	super(difficulty, season)
	if WPK.active() and bool(WPK.setting("start_kit")):
		var f := FileAccess.open(WPK.KIT_FLAG, FileAccess.WRITE)
		if f:
			f.store_string("1")
			f.close()


func LoadCharacter():
	super()
	if FileAccess.file_exists(WPK.KIT_FLAG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(WPK.KIT_FLAG))
		var ui = get_tree().current_scene.get_node_or_null("/root/Map/Core/UI/Interface")
		WPK.give_start_kit(ui)
