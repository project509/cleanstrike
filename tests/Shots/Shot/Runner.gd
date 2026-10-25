extends Node
var started := false
func wait(s): await get_tree().create_timer(s, true, false, true).timeout
func shot(name):
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://cleanstrike/" + name)
func _ready():
	get_tree().create_timer(200.0, true, false, true).timeout.connect(func(): get_tree().quit())
	run.call_deferred()
func run():
	var gd = load("res://Resources/GameData.tres")
	while get_node_or_null("/root/Map/Core/UI/Interface") == null or gd.isCaching:
		await wait(0.5)
	await wait(3.0)
	var tr = load("res://Resources/Transition.tscn").instantiate()
	tr.nextMap = "School"; tr.currentMap = "Village"; tr.nextZone = "Area 05"; tr.time = 1.0
	get_tree().current_scene.add_child(tr)
	gd.isTransitioning = true
	tr.Interact()
	await wait(1.0)
	await shot("shot_picker.png")
	var ui = get_node("/root/Map/Core/UI")
	var picker = ui.get_node("RTT_DestinationPicker")
	picker._cards[1].mouse_entered.emit()
	await wait(0.3)
	await shot("shot_picker_hover.png")
	picker._cancel()
	await wait(0.5)
	ui.ToggleInterface()
	await wait(1.0)
	var interface = ui.get_node("Interface")
	interface._on_map_pressed()
	await wait(1.0)
	await shot("shot_worldmap.png")
	get_tree().quit()
