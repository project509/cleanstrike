# Renders UI and map screenshots into user://cleanstrike/shot_*.png.
extends Node
var started := false

func wait(s): await get_tree().create_timer(s, true, false, true).timeout

func shot(name):
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://cleanstrike/" + name)

func _ready():
	get_tree().create_timer(400.0, true, false, true).timeout.connect(func(): get_tree().quit())
	run.call_deferred()

func map_ready(name: String) -> bool:
	var gd = load("res://Resources/GameData.tres")
	var m = get_node_or_null("/root/Map")
	return m != null and m.mapName == name and not gd.isCaching and not gd.isTransitioning and get_node_or_null("/root/Map/Core/Controller") != null

func run():
	var gd = load("res://Resources/GameData.tres")
	while not map_ready("Tutorial"):
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
	ui.get_node("RTT_DestinationPicker").choose("Customs")
	while not map_ready("Customs"):
		await wait(0.5)
	await wait(3.0)
	await customs_views()
	get_tree().quit()

func ground(x: float, z: float) -> float:
	var space = get_node("/root/Map").get_world_3d().direct_space_state
	var q = PhysicsRayQueryParameters3D.create(Vector3(x, 300, z), Vector3(x, -50, z))
	q.collision_mask = 1
	var hits := 0
	var hit = space.intersect_ray(q)
	# Skip trees and roofs: keep casting until the terrain is hit.
	var last = hit
	while hit and not String(hit.collider.get_path()).contains("Terrain/Elements") and hits < 60:
		last = hit
		q.from = hit.position + Vector3(0, -0.05, 0)
		hit = space.intersect_ray(q)
		hits += 1
	if not hit:
		hit = last
	if not hit:
		return 0.0
	# Inside buildings stand on the floor, not the terrain under it.
	var q2 = PhysicsRayQueryParameters3D.create(Vector3(x, hit.position.y + 2.5, z), Vector3(x, hit.position.y - 1.0, z))
	var h2 = space.intersect_ray(q2)
	return h2.position.y if h2 else hit.position.y

func customs_views():
	Simulation.time = 1200.0
	Simulation.weather = "Neutral"
	get_node("/root/Map/Core/UI").hide()
	var cam := Camera3D.new()
	cam.far = 3000.0
	cam.fov = 70.0
	get_node("/root/Map").add_child(cam)
	# [name, eye x, eye height above ground, eye z, target x, target height, target z] in layout metres
	var views = [
		["overview", 330, 150, 640, 560, 0, 330],
		["main_road", 250, 1.7, 343, 420, 3, 362],
		["tank_farm", 150, 1.7, 333, 90, 12, 270],
		["warehouses", 262, 1.7, 345, 320, 6, 275],
		["scav_base", 470, 1.7, 362, 515, 14, 262],
		["boiler", 548, 1.7, 384, 595, 10, 305],
		["red_warehouse", 868, 1.7, 352, 905, 6, 262],
		["dorms", 505, 1.7, 418, 505, 6, 470],
		["bridge", 702, 2.5, 372, 795, 4, 351],
		["wh5_close", 212, 1.7, 345, 228, 5, 315],
		["garages", 1000, 1.7, 304, 990, 2, 270],
		["forest_edge", 300, 1.7, 420, 340, 3, 380],
		["dorms_outside", 497, 1.7, 470, 523, 6, 462],
		["dorm_corridor", 522.5, 1.65, 450.0, 522.5, 1.5, 485.0],
		["dorm_room", 521.0, 1.6, 462.9, 516.2, 1.1, 461.2],
		["dorm_stairs", 524.0, 1.65, 447.8, 517.5, 2.5, 446.5],
	]
	for v in views:
		var ex = float(v[1]) - 540.0
		var ez = float(v[3]) - 340.0
		var tx = float(v[4]) - 540.0
		var tz = float(v[6]) - 340.0
		var eye = Vector3(ex, ground(ex, ez) + float(v[2]), ez)
		var target = Vector3(tx, ground(tx, tz) + float(v[5]), tz)
		print("[shot] %s eye=%s target=%s" % [v[0], eye, target])
		cam.global_position = eye
		cam.look_at(target, Vector3.UP)
		cam.make_current()
		await wait(2.5)
		cam.make_current()
		await shot("shot_customs_%s.png" % v[0])
