# Road to Tarkov: travel points that lead to School offer Customs as well.
extends "res://Scripts/Transition.gd"

const RTT = preload("res://RoadToTarkov/RTT.gd")
const Picker = preload("res://RoadToTarkov/Customs/Picker.gd")

var rtt_picker: Control


func Interact():
	# Leaving the Customs preview goes back to the menu, never saving.
	if gameData.tutorial and currentMap == "Customs":
		Loader.LoadScene("Menu")
		return
	if not RTT_OffersCustoms():
		super()
		return
	if rtt_picker and is_instance_valid(rtt_picker):
		return
	var ui = get_tree().current_scene.get_node_or_null("/root/Map/Core/UI")
	if ui == null:
		super()
		return
	rtt_picker = Picker.new()
	ui.add_child(rtt_picker)
	rtt_picker.setup(self)
	if ui.has_method("UIOpen"):
		ui.UIOpen()
	rtt_picker.chosen.connect(_rtt_on_chosen)
	rtt_picker.cancelled.connect(_rtt_on_cancelled.bind(ui))


func RTT_OffersCustoms() -> bool:
	return RTT.customs_enabled() and nextMap == "School" and not locked and not tutorialExit


func _rtt_on_chosen(map_name: String) -> void:
	if map_name == "Customs":
		var original := nextMap
		nextMap = "Customs"
		super.Interact()
		nextMap = original
	else:
		super.Interact()


func _rtt_on_cancelled(ui) -> void:
	gameData.isTransitioning = false
	gameData.transition = false
	if ui and ui.has_method("UIClose"):
		ui.UIClose()
