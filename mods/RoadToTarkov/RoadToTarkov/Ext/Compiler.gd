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
	# Customs' navmesh uses 0.24 m cells (it is much bigger than Vostok's
	# maps); the navigation map must use the same cell size.
	var nav_map: RID = get_viewport().get_world_3d().get_navigation_map()
	NavigationServer3D.map_set_cell_size(nav_map, 0.24)
	# Godot caps a path search at 4096 polygons; Customs' long routes need
	# more, or scavs only get partial paths. Raise it on every agent.
	for n in get_tree().current_scene.find_children("*", "NavigationAgent3D", true, false):
		_rtt_agent_budget(n)
	if not get_tree().node_added.is_connected(_rtt_on_node_added):
		get_tree().node_added.connect(_rtt_on_node_added)
	NavigationServer3D.map_set_use_edge_connections(nav_map, true)
	NavigationServer3D.map_set_edge_connection_margin(nav_map, 0.5)
	controller.global_position = Vector3(0, 2, 0)
	if gameData.tutorial:
		# Preview: no save is read; fixed daylight.
		Simulation.simulate = false
		Simulation.time = 1000.0
		Simulation.weather = "Neutral"
	else:
		Loader.LoadWorld()
		Loader.LoadCharacter()
		Simulation.simulate = true

	var preview = get_tree().current_scene.find_child("Spawn_Preview", true, false) if gameData.tutorial else null
	if preview:
		controller.global_transform = Transform3D(Basis.looking_at(-preview.global_transform.basis.z, Vector3.UP), preview.global_position)
		_rtt_spawn_done()
		return
	var target := "Transition_" + str(gameData.previousMap)
	for t in get_tree().get_nodes_in_group("Transition"):
		var owner_node = t.owner
		if owner_node and owner_node.name == target and owner_node.spawn:
			var spawn_point: Node3D = owner_node.spawn
			controller.global_transform.basis = spawn_point.global_transform.basis.rotated(Vector3.UP, deg_to_rad(180))
			controller.global_position = spawn_point.global_position
			break

	_rtt_spawn_done()


func _rtt_spawn_done() -> void:
	gameData.isTransitioning = false
	gameData.isSleeping = false
	gameData.isOccupied = false
	gameData.freeze = false


const PATH_SEARCH_POLYGONS := 30000


func _rtt_on_node_added(n: Node) -> void:
	if n is NavigationAgent3D:
		_rtt_agent_budget(n)


func _rtt_agent_budget(agent: Node) -> void:
	if "path_search_max_polygons" in agent:
		agent.set("path_search_max_polygons", PATH_SEARCH_POLYGONS)
