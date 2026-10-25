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
	while hit and not String(hit.collider.get_path()).contains("Terrain/Elements") and hits < 8:
		q.from = hit.position + Vector3(0, -0.05, 0)
		hit = space.intersect_ray(q)
		hits += 1
	return hit.position.y if hit else 0.0

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
		["boiler", 560, 1.7, 362, 595, 10, 300],
		["red_warehouse", 880, 1.7, 330, 905, 6, 262],
		["dorms", 505, 1.7, 418, 505, 6, 470],
		["bridge", 702, 2.5, 372, 795, 4, 351],
	]
	for v in views:
		var ex = float(v[1]) - 540.0
		var ez = float(v[3]) - 340.0
		var tx = float(v[4]) - 540.0
		var tz = float(v[6]) - 340.0
		var eye = Vector3(ex, ground(ex, ez) + float(v[2]), ez)
		var target = Vector3(tx, ground(tx, tz) + float(v[5]), tz)
		cam.global_position = eye
		cam.look_at(target, Vector3.UP)
		cam.make_current()
		await wait(2.5)
		cam.make_current()
		await shot("shot_customs_%s.png" % v[0])
