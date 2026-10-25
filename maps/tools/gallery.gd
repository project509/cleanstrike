# Asset gallery: renders each scene in a list from a 3/4 view to PNG.
#   Godot --path <RTVProject> res://cs_tools/gallery/Gallery.tscn --windowed --position -3000,100 -- <list.json> <out_dir>
extends Node3D

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var paths: Array = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var out: String = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	# The game's Loader singleton is a full-screen loading overlay; hide it.
	var loader := get_node_or_null("/root/Loader")
	if loader is CanvasLayer:
		(loader as CanvasLayer).visible = false
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(800, 800)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.32, 0.31, 0.28)
	ground.material_override = gm
	add_child(ground)
	var cam := Camera3D.new()
	cam.far = 2000
	add_child(cam)
	cam.make_current()
	for p in paths:
		if not ResourceLoader.exists(p):
			continue
		var ps = load(p)
		if not (ps is PackedScene):
			continue
		var inst: Node = ps.instantiate()
		add_child(inst)
		var acc := [null]
		_merge(inst, Transform3D.IDENTITY, acc)
		if acc[0] == null:
			inst.queue_free()
			continue
		var a: AABB = acc[0]
		var c := a.get_center()
		var r := maxf(a.size.length() / 2.0, 1.0)
		cam.position = c + Vector3(1.0, 0.65, 1.2).normalized() * r * 1.9
		cam.look_at(c, Vector3.UP)
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(480, 270)
		img.save_png(out.path_join(p.get_file().get_basename() + ".png"))
		inst.queue_free()
		await get_tree().process_frame
	get_tree().quit()

func _merge(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh and (n as MeshInstance3D).layers != 0 and (n as MeshInstance3D).visible:
		var a: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		acc[0] = a if acc[0] == null else (acc[0] as AABB).merge(a)
	for ch in n.get_children():
		_merge(ch, t, acc)
