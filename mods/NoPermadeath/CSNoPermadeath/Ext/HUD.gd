# No Permadeath: don't show permadeath warnings for deaths that no longer
# delete anything (the skull icon, and the "Permadeath Zone" travel hint).
extends "res://Scripts/HUD.gd"

const M = preload("res://CSNoPermadeath/Mod.gd")


func _physics_process(delta):
	super(delta)
	if permadeath.visible and M.spares(int(gameData.difficulty)):
		permadeath.hide()


func Transition(transitionData):
	super(transitionData)
	if transitionData.nextZone == "Vostok" and M.spares(int(gameData.difficulty)):
		detailsHint.text = "Permadeath off"
		detailsHint.modulate = Color.ORANGE
