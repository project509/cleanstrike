# Road to Tarkov: spawning for Customs, and for coming back from it.
extends "res://Scripts/Compiler.gd"


func Spawn():
	var map = get_tree().current_scene.get_node_or_null("/root/Map")
	if map and map.mapName == "Customs":
		_rtt_spawn_customs()
		return
	# Customs sits past the school, so coming back puts you on the School road.
	if gameData.previousMap == "Customs":
		gameData.previousMap = "School"
	super()


func _rtt_spawn_customs() -> void:
	controller.global_position = Vector3(0, 2, 0)
	Loader.LoadWorld()
	Loader.LoadCharacter()
	Simulation.simulate = true

	var target := "Transition_" + str(gameData.previousMap)
	for t in get_tree().get_nodes_in_group("Transition"):
		var owner_node = t.owner
		if owner_node and owner_node.name == target and owner_node.spawn:
			var spawn_point: Node3D = owner_node.spawn
			controller.global_transform.basis = spawn_point.global_transform.basis.rotated(Vector3.UP, deg_to_rad(180))
			controller.global_position = spawn_point.global_position
			break

	gameData.isTransitioning = false
	gameData.isSleeping = false
	gameData.isOccupied = false
	gameData.freeze = false
