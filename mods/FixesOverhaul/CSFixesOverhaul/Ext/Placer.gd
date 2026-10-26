# Fixes Overhaul, moving furniture in decor mode:
#  - "place" at a spot where it can't go used to do nothing (you were stuck
#    holding it). Now it goes back where it was.
#  - Sending it to a full catalog deleted it; now it goes back instead.
extends "res://Scripts/Placer.gd"

const FO = preload("res://CSFixesOverhaul/Mod.gd")

var fo_start: Transform3D
var fo_has_start := false


func _input(event):
	if FO.on("catalog_full") and gameData.isPlacing and gameData.decor and placable and furniture \
			and Input.is_action_just_pressed("interact") and not FO.catalog_room(self, furniture.itemData):
		FO_PutBack("Catalog is full: put back where it was")
		get_viewport().set_input_as_handled()
		return
	super(event)


func _physics_process(delta):
	if FO.on("decor_cancel") and gameData.decor and gameData.isPlacing and placable and furniture \
			and not gameData.freeze and Input.is_action_just_pressed("place") and not furniture.CanPlace():
		FO_PutBack("No room there: put back where it was")
		return
	var was: bool = gameData.isPlacing
	super(delta)
	if not was and gameData.isPlacing and gameData.decor and placable:
		fo_start = placable.global_transform
		fo_has_start = true


func FO_PutBack(message: String) -> void:
	if fo_has_start and placable:
		placable.global_transform = fo_start
	if furniture:
		furniture.ResetMove()
	placable = null
	furniture = null
	gameData.isPlacing = false
	Loader.Message(message, Color.ORANGE)
