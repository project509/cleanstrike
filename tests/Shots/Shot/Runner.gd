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
	# SHOTS=<mode> tools/shots.sh renders one UI instead of the maps.
	for mode in ["loot", "trader", "hud", "reticle", "blood", "skills", "icons", "lights", "grades", "zombies", "zgore", "zmap", "zperf", "scar", "scareq"]:
		if FileAccess.file_exists("user://cleanstrike/shot_mode_" + mode):
			await call(mode + "_views")
			get_tree().quit()
			return
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
	await spawn_views()
	if OS.get_cmdline_user_args().has("--perf") or FileAccess.file_exists("user://cleanstrike/perf_mode"):
		await perf_run("Customs", [[330, 150, 640, 560, 0, 330], [250, 1.7, 343, 420, 3, 362], [505, 1.7, 418, 505, 6, 470], [702, 2.5, 372, 795, 4, 351], [300, 1.7, 420, 340, 3, 380]])
		Loader.LoadScene("Village")
		while not map_ready("Village"):
			await wait(0.5)
		await wait(3.0)
		await perf_run("Village", [])
	get_tree().quit()

func perf_sample(label: String) -> void:
	await wait(1.5)
	var frames := 0
	var t0 := Time.get_ticks_usec()
	var worst := 0.0
	var last := t0
	var dc := 0
	var prims := 0
	var objs := 0
	while Time.get_ticks_usec() - t0 < 3000000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		frames += 1
		dc = maxi(dc, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		prims = maxi(prims, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		objs = maxi(objs, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	var avg := 3000.0 / frames
	var line := "%s avg %.1f ms (%.0f fps) worst %.1f ms | draws %d objects %d prims %.1fM | vram %.0f MB" % [label, avg, 1000.0 / avg, worst, dc, objs, prims / 1e6, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0]
	print("[perf] " + line)
	var f := FileAccess.open("user://cleanstrike/perf.txt", FileAccess.READ_WRITE if FileAccess.file_exists("user://cleanstrike/perf.txt") else FileAccess.WRITE)
	f.seek_end()
	f.store_line(line)
	f.close()

func perf_run(map: String, views: Array) -> void:
	get_node("/root/Map/Core/UI").hide()
	if views.is_empty():
		# Vostok map: sample from where the player stands plus a high view.
		await perf_sample(map + " player")
		var c := Camera3D.new()
		c.far = 3000.0
		get_node("/root/Map").add_child(c)
		c.global_position = Vector3(0, 150, 300)
		c.look_at(Vector3.ZERO, Vector3.UP)
		c.make_current()
		await perf_sample(map + " overview")
		return
	var cam := Camera3D.new()
	cam.far = 3000.0
	cam.fov = 70.0
	get_node("/root/Map").add_child(cam)
	var k := 0
	for v in views:
		var ex = float(v[0]) - 540.0
		var ez = float(v[2]) - 340.0
		var tx = float(v[3]) - 540.0
		var tz = float(v[5]) - 340.0
		cam.global_position = Vector3(ex, ground(ex, ez) + float(v[1]), ez)
		cam.look_at(Vector3(tx, ground(tx, tz) + float(v[4]), tz), Vector3.UP)
		cam.make_current()
		await perf_sample("%s view %d" % [map, k])
		k += 1

# Trader screen (Tutorial's trader), each tab Better Traders adds.
func trader_views():
	var ui = get_node("/root/Map/Core/UI")
	var interface = get_node("/root/Map/Core/UI/Interface")
	var trader = null
	for n in get_tree().current_scene.find_children("*", "", true, false):
		if n is Trader:
			trader = n
			break
	if trader == null:
		print("[CSShot] no trader in this map")
		return
	trader.Activate()
	ui.OpenTrader(trader)
	await wait(1.5)
	await shot("shot_trader_supply.png")
	for b in ["Furniture", "Stock", "Dailies", "Tasks"]:
		var btn = interface.get_node_or_null("Trader/Panel/Buttons/" + b)
		if btn:
			btn.pressed.emit()
			btn.button_pressed = true
			await wait(0.8)
			await shot("shot_trader_%s.png" % b.to_lower())


# Tarkov Looting: search in progress (grey ghost), unknown silhouettes, examining.
func loot_views():
	var ui = get_node("/root/Map/Core/UI")
	var interface = get_node("/root/Map/Core/UI/Interface")
	var target = null
	var stack: Array = [get_tree().current_scene]
	while stack.size() > 0 and target == null:
		var n = stack.pop_back()
		if n is LootContainer and not n.locked and not n.furniture:
			target = n
		stack.append_array(n.get_children())
	if target == null:
		return
	target.loot.clear()
	for path in ["res://Items/Weapons/AKM/AKM.tres", "res://Items/Weapons/AKM/AKM_Magazine.tres"]:
		target.CreateLoot(load(path))
	var master = load("res://Loot/LT_Master.tres").items
	for i in 8:
		target.CreateLoot(master.pick_random())
	ui.OpenContainer(target)
	await wait(2.2)
	await shot("shot_loot_searching.png")
	while interface.containerGrid.get_children().any(func(i): return i.get_meta("tl_hidden", false)):
		await wait(0.5)
	await wait(0.6)
	await shot("shot_loot_unknown.png")
	for i in interface.containerGrid.get_children():
		if interface.TL_Examine(i):
			break
	await wait(0.8)
	await shot("shot_loot_examining.png")


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
		["scav_hall", 545, 1.7, 300, 500, 10, 255],
		["gantries", 300, 1.7, 345, 285, 6, 315],
		["trailer_park", 982, 1.7, 256, 982, 2, 232],
		["west_checkpoint", 150, 1.7, 395, 120, 3, 362],
		["bridge_checkpoint", 680, 1.7, 372, 720, 3, 352],
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


# First-person views from the preview start and every exit's spawn point.
func spawn_views():
	var cam := Camera3D.new()
	cam.far = 3000.0
	cam.fov = 75.0
	get_node("/root/Map").add_child(cam)
	var targets: Array = []
	var sp = get_tree().current_scene.find_child("Spawn_Preview", true, false)
	if sp: targets.append(["preview_start", sp.global_position, -sp.global_transform.basis.z])
	for t in get_tree().get_nodes_in_group("Transition"):
		var o = t.owner
		if o and o.get("spawn"):
			var s3: Node3D = o.spawn
			targets.append(["spawn_" + String(o.name).replace("Transition_", ""), s3.global_position, s3.global_transform.basis.z])
	for tg in targets:
		var pos: Vector3 = tg[1]
		var dir: Vector3 = tg[2]
		dir.y = 0.0
		cam.global_position = Vector3(pos.x, ground(pos.x, pos.z) + 1.7, pos.z)
		cam.look_at(cam.global_position + dir.normalized() * 10.0 + Vector3(0, -0.5, 0), Vector3.UP)
		cam.make_current()
		print("[shot] %s at layout (%.0f, %.0f)" % [tg[0], pos.x + 540.0, pos.z + 340.0])
		await wait(2.0)
		cam.make_current()
		await shot("shot_%s.png" % tg[0])


# Plain gameplay view with the HUD (CleanStrike HUD's bars and compass).
func hud_views():
	var gd = load("res://Resources/GameData.tres")
	gd.health = 72.0
	gd.bodyStamina = 40.0
	gd.hydration = 55.0
	if ResourceLoader.exists("res://CSTacticalWatch/Mod.gd"):   # wrist panel too
		var tw = load("res://CSTacticalWatch/Mod.gd")
		tw.overrides = {"needs_watch": false}
		tw.shown = true
	await wait(1.0)
	await shot("shot_hud.png")


# Reticles: each style through a sight glass straight ahead (the reticle is
# projected at infinity, so it only shows looking straight through).
func reticle_views():
	var R = load("res://CSReticles/Mod.gd")
	var cam = get_viewport().get_camera_3d()
	var styles := ["Dot", "Circle dot", "Chevron", "Cross", "Circle cross", "Triangle"]
	var colors := ["Red", "Green", "Amber", "Blue", "White", "Magenta"]
	var q := MeshInstance3D.new()
	q.mesh = QuadMesh.new()
	q.mesh.size = Vector2(0.3, 0.3)
	get_tree().current_scene.add_child(q)
	q.global_transform = cam.global_transform
	q.global_position = cam.global_position - cam.global_basis.z * 0.4
	for i in styles.size():
		R.overrides = {"style": styles[i], "color": colors[i]}
		R.apply()
		q.material_override = load(R.MATERIALS[0])
		await wait(0.5)
		await shot("shot_reticle_%d.png" % i)
	q.queue_free()
	R.overrides = {}
	R.apply()


# Death and Hit Effects: a pool and splats on the floor ahead, kill marker.
func blood_views():
	var D = load("res://CSDeathHitEffects/Mod.gd")
	var cam = get_viewport().get_camera_3d()
	var player = get_node("/root/Map/Core/Controller")
	var ahead: Vector3 = player.global_position - Vector3(cam.global_basis.z.x, 0, cam.global_basis.z.z).normalized() * 6.0
	D.overrides = {"pool_seconds": 0.3}
	var body := Node3D.new()
	get_tree().current_scene.add_child(body)
	body.global_position = ahead
	D.pool(body)
	for i in 3:
		D.splatter(player, ahead + Vector3(randf_range(-1, 1), 1.0, randf_range(-1, 1)), Vector3.DOWN, [player.get_rid()])
	await wait(1.0)
	D.marker(get_tree(), true)
	await wait(0.05)
	await shot("shot_blood.png")
	D.overrides = {}


# Progression: the Skills panel on the Character view (inventory open).
func skills_views():
	var P = load("res://CSProgression/Mod.gd")
	P._state = {"xp": 140, "level": 4, "points": 2, "ranks": {"endurance": 3, "strength": 2, "scavenger": 1}}
	P._loaded = true
	var ui = get_node("/root/Map/Core/UI")
	ui.ToggleInterface()
	var interface = get_node("/root/Map/Core/UI/Interface")
	if not interface.visible:
		interface.Open()
		interface.show()
	interface.PG_Build()
	interface.pg_button.button_pressed = true
	interface.PG_Show(true)
	await wait(0.5)
	await shot("shot_skills.png")


# Item icons: each scene in user://cleanstrike/icon_list.txt rendered alone on
# a transparent background, 3/4 view, to dist/shots/icon_<name>.png.
func icons_views():
	var f := FileAccess.open("user://cleanstrike/icon_list.txt", FileAccess.READ)
	if f == null:
		return
	for line in f.get_as_text().split("
", false):
		var path := line.strip_edges()
		if path == "":
			continue
		var vp := SubViewport.new()
		vp.size = Vector2i(512, 512)
		vp.transparent_bg = true
		vp.own_world_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.55, 0.55, 0.55)
		vp.add_child(env)
		var obj = load(path).instantiate()
		vp.add_child(obj)
		var box := AABB()
		var first := true
		for m in obj.find_children("*", "MeshInstance3D", true, false):
			if m.mesh and m.visible and m.layers != 0:
				var b: AABB = m.global_transform * m.get_aabb()
				box = b if first else box.merge(b)
				first = false
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-40, -35, 0)
		vp.add_child(sun)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = maxf(box.size.y, maxf(box.size.x, box.size.z)) * 1.25
		vp.add_child(cam)
		var c := box.get_center()
		cam.look_at_from_position(c + Vector3(1.0, 0.7, 1.2).normalized() * 10.0, c)
		await wait(0.5)
		var img := vp.get_texture().get_image()
		img.save_png("user://cleanstrike/shot_icon_%s.png" % path.get_file().get_basename())
		vp.queue_free()


# Hideout Lights: every fixture in a row, turned the way it faces when placed
# (+z out of the wall, towards the camera).
func lights_views():
	var HL = load("res://CSHideoutLights/Mod.gd")
	while HL.scenes.size() < HL.FIXTURES.size():
		await wait(0.2)
	var cam = get_viewport().get_camera_3d()
	var player = get_node("/root/Map/Core/Controller")
	var fwd: Vector3 = -Vector3(cam.global_basis.z.x, 0, cam.global_basis.z.z).normalized()
	var right: Vector3 = fwd.cross(Vector3.UP)
	var i := 0
	for f in HL.FIXTURES:
		var fx = HL.scenes[f].instantiate()
		get_tree().current_scene.add_child(fx)
		fx.global_basis = Basis.looking_at(fwd, Vector3.UP)   # +z towards the camera
		fx.global_position = player.global_position + fwd * 3.0 + right * (i - 3) * 0.7 + Vector3(0, 0.6 if HL.FIXTURES[f][3] else 0.0, 0)
		i += 1
	await wait(1.0)
	await shot("shot_lights.png")


# Visuals: the same view through each colour grade.
func grades_views():
	var V = load("res://CSVisuals/Mod.gd")
	var boot = get_node("/root/CSVisualsBoot")
	await wait(1.0)
	for p in V.PRESETS:
		V.overrides = {"preset": p}
		boot.apply()
		await wait(0.4)
		await shot("shot_grade_%s.png" % p.replace(" ", "_"))
	V.overrides = {}


# CleanStrike Zombies: a pack of walkers, a runner and crawlers coming at you.
func zombies_views():
	var ZM = load("res://CSZombies/Mod.gd")
	var cam = get_viewport().get_camera_3d()
	var player = get_node("/root/Map/Core/Controller")
	var fwd: Vector3 = -Vector3(cam.global_basis.z.x, 0, cam.global_basis.z.z).normalized()
	var right: Vector3 = fwd.cross(Vector3.UP)
	var feet: Vector3 = player.global_position
	var space = player.get_world_3d().direct_space_state
	var pack := [["walk", -1.2, 5.0], ["walk_2", 0.6, 6.0], ["run", 0.0, 8.5], ["walk_3", 1.8, 9.0], ["stumble", -2.4, 10.0],
		["crawl", -0.6, 3.6], ["crawl_run", 1.2, 4.4], ["walk", -1.6, 12.0], ["idle_scratch", 2.6, 12.5]]
	for p in pack:
		var z: Node3D = ZM.scene().instantiate()
		get_tree().current_scene.add_child(z)
		z.active = false
		var at: Vector3 = feet + fwd * p[2] + right * p[1]
		var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at + Vector3.DOWN * 4.0, 1)
		var hit = space.intersect_ray(q)
		if hit:
			at.y = hit.position.y
		z.global_position = at
		z.global_basis = Basis.looking_at((feet - at) * Vector3(1, 0, 1), Vector3.UP)   # the model faces -z: towards you
		var ap: AnimationPlayer = z.get_node("Model/AnimationPlayer")
		ap.play(p[0])
		ap.seek(randf() * ap.current_animation_length, true)
	await wait(1.5)
	await shot("shot_zombies.png")


# CleanStrike Zombies: limbs shot off (baked limbs on the floor, a crawler).
func zgore_views():
	var ZM = load("res://CSZombies/Mod.gd")
	var cam = get_viewport().get_camera_3d()
	var player = get_node("/root/Map/Core/Controller")
	var fwd: Vector3 = -Vector3(cam.global_basis.z.x, 0, cam.global_basis.z.z).normalized()
	var right: Vector3 = fwd.cross(Vector3.UP)
	var feet: Vector3 = player.global_position
	var zs := []
	for i in 2:
		var z = ZM.scene().instantiate()
		get_tree().current_scene.add_child(z)
		z.global_position = feet + fwd * 4.0 + right * (i * 1.6 - 0.8)
		z.global_basis = Basis.looking_at(-fwd, Vector3.UP)   # -z (its front) towards you
		z.Activate("Wander")
		z.active = false                    # posed: no AI, animation still plays
		z.anim.play("idle")
		zs.append(z)
	await wait(0.8)
	zs[0].Hit("arm_r_upper", 200.0, right, null, zs[0].global_position + Vector3.UP * 1.3)
	zs[1].Hit("leg_l_upper", 200.0, -right, null, zs[1].global_position + Vector3.UP * 0.6)
	zs[1].anim.play("crawl")
	await wait(1.2)
	await shot("shot_zgore.png")


# CleanStrike Zombies on a real map: spawns, navigation, a gunshot, the pack.
func zmap_views():
	var ZM = load("res://CSZombies/Mod.gd")
	var gd = load("res://Resources/GameData.tres")
	Loader.LoadScene("Village")
	while not map_ready("Village"):
		await wait(0.5)
	await wait(12.0)                                  # pools fill, first spawns
	var zs: Array = ZM.living.filter(func(z): return is_instance_valid(z) and z.active)
	var cam = get_viewport().get_camera_3d()
	var me: Vector3 = gd.playerPosition
	var start := {}
	for z in zs:
		start[z] = z.global_position.distance_to(me)
	print("[ZMAP] active zombies %d, pooled %d, nav map %s" % [zs.size(), ZM.living.size(), str(zs[0].agent.get_navigation_map()) if zs.size() > 0 else "-"])
	ZM.note_shot(me)
	await wait(1.5)
	var heard := zs.filter(func(z): return z.state in [z.S.INVESTIGATE, z.S.CHASE]).size()
	await wait(25.0)
	var closer := 0
	var with_path := 0
	for z in zs:
		if is_instance_valid(z) and z.global_position.distance_to(me) < start[z] - 3.0:
			closer += 1
		if is_instance_valid(z) and not z.agent.get_current_navigation_path().is_empty():
			with_path += 1
	print("[ZMAP] heard the shot %d / %d, closer by 3 m+ %d, with nav path %d" % [heard, zs.size(), closer, with_path])
	var near = null
	for z in zs:
		if is_instance_valid(z) and (near == null or z.global_position.distance_to(me) < near.global_position.distance_to(me)):
			near = z
	if near:
		print("[ZMAP] nearest %.1f m, state %d" % [near.global_position.distance_to(me), near.state])
		cam.look_at(near.global_position + Vector3.UP * 1.2, Vector3.UP)
	await wait(0.3)
	await shot("shot_zmap.png")


# CleanStrike Zombies: frame times with a big horde hunting you on Village.
func zperf_views():
	var ZM = load("res://CSZombies/Mod.gd")
	var gd = load("res://Resources/GameData.tres")
	ZM.overrides = {"horde": 4.0, "start_share": 1.0}
	Loader.LoadScene("Village")
	while not map_ready("Village"):
		await wait(0.5)
	await wait(10.0)
	var base := await _frame_stats(5.0)
	var zs: Array = ZM.living.filter(func(z): return is_instance_valid(z) and z.active)
	for z in zs:                                      # bring them all in, hunting
		z.global_position = gd.playerPosition + Vector3(randf_range(-25, 25), 0, randf_range(-25, 25))
		z.Hear(gd.playerPosition, false)
	await wait(2.0)
	var hunt := await _frame_stats(8.0)
	print("[ZPERF] zombies %d | before: avg %.1f ms, worst %.1f ms | hunting: avg %.1f ms, worst %.1f ms" % [zs.size(), base[0], base[1], hunt[0], hunt[1]])
	ZM.overrides = {}


func _frame_stats(seconds: float) -> Array:
	var times := []
	var t0 := Time.get_ticks_usec()
	var last := t0
	while Time.get_ticks_usec() - t0 < seconds * 1e6:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	times.sort()
	var avg := 0.0
	for x in times:
		avg += x
	return [avg / maxf(1, times.size()), times[int(times.size() * 0.99)]]


# Weapons Pack: the SCAR rig held in first person, and side on.
func scar_views():
	var WP = load("res://CSWeaponsPack/Mod.gd")
	var cam = get_viewport().get_camera_3d()
	var rig: Node3D = WP.build_scar_rig().instantiate()
	cam.add_child(rig)
	rig.position = Vector3(0.12, -0.16, -0.32)
	rig.rotation = Vector3(0, PI, 0)
	for m in rig.find_children("*", "MeshInstance3D", true, false):
		m.layers = 1
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	await wait(1.0)
	await shot("shot_scar_fp.png")
	rig.position = Vector3(0, -0.05, -0.75)
	rig.rotation = Vector3(0, PI / 2.0, 0)
	await wait(0.5)
	await shot("shot_scar_side.png")


# Weapons Pack: the SCAR equipped the player's way (into the primary slot,
# then loaded), hip and aimed with an EXPS; the KAR-21 first for comparison.
func _equip(data, nested: Array) -> Node:
	var gd = load("res://Resources/GameData.tres")
	var ui = get_node("/root/Map/Core/UI/Interface")
	var manager = get_node("/root/Map/Core/Camera/Manager")
	manager.ClearRig()
	for c in manager.primarySlot.get_children():
		c.queue_free()
	await wait(0.3)
	var sd := SlotData.new()
	sd.itemData = data
	sd.amount = 20
	for n in nested:
		sd.nested.append(n)
	ui.Create(sd, ui.inventoryGrid, false)
	await wait(0.3)
	var item = null
	for c in ui.inventoryGrid.get_children():
		if c is Item and c.slotData.itemData == data:
			item = c
	ui.inventoryGrid.Pick(item)
	ui.Equip(item, manager.primarySlot)
	gd.primary = true
	manager.LoadPrimary()
	await wait(2.5)
	print("[SCAREQ] ", data.name, " in hand: ", manager.get_children().map(func(c): return c.name))
	return manager


func scareq_views():
	var WP = load("res://CSWeaponsPack/Mod.gd")
	var gd = load("res://Resources/GameData.tres")
	while not (Engine.has_meta("cs_items") and Engine.get_meta("cs_items").has("CS_SCAR_Rig")):
		await wait(0.2)
	await _equip(load("res://Items/Weapons/KAR-21/KAR-21_308.tres"), [])
	await shot("shot_kar_hip.png")
	var mgr = await _equip(WP.scar_item(), [])
	await shot("shot_scar_hip.png")
	# The KAR-21 in the same hands, same moment, drawn as a ghost: do they line up?
	var kar: Node3D = load("res://Items/Weapons/KAR-21/KAR-21_308_Rig.tscn").instantiate()
	var ghost := StandardMaterial3D.new()
	ghost.albedo_color = Color(0.2, 0.9, 1.0, 0.45)
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.no_depth_test = true
	mgr.add_child(kar)
	for m in kar.find_children("*", "MeshInstance3D", true, false):
		if m.name == "Arms":
			m.visible = false
		else:
			m.material_override = ghost
	await wait(1.0)
	await shot("shot_scar_vs_kar.png")
	kar.queue_free()
	await _equip(WP.scar_item(), [load("res://Items/Attachments/EXPS/EXPS.tres")])
	gd.isAiming = true
	await wait(1.5)
	await shot("shot_scar_ads.png")
	gd.isAiming = false
