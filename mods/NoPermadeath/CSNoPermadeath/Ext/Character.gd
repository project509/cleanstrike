# No Permadeath: a death in a permadeath zone (or on Hardcore) works like a
# normal death, so your saves are never deleted. Optionally you keep your
# gear when you respawn at your shelter.
extends "res://Scripts/Character.gd"

const M = preload("res://CSNoPermadeath/Mod.gd")


func Death():
	if not M.active() or gameData.tutorial:
		super()
		return
	if gameData.permadeath and not gameData.shelter and M.spares(int(gameData.difficulty)):
		# The game's normal death: world saved, character reset, back to
		# your shelter, and the death screen says "Character died".
		gameData.permadeath = false
		M.say("Permadeath off: this death works like a normal one.")
	var mode := M.keep_mode()
	if mode == M.LOSE_ALL or gameData.permadeath:
		super()
		return
	var kept := M.capture_character()
	super()
	M.restore_gear(kept, mode)
