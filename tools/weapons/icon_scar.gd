extends Node
# The SCAR inventory icon: side view, transparent, 6x2 cells (768x256).
func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1536, 512)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.65, 0.65, 0.65)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 70, 0)
	vp.add_child(sun)
	var scar: Node3D = load("res://CSWeapons/Model/SCAR_Parts.scn").instantiate()
	vp.add_child(scar)
	for n in scar.find_children("*", "MeshInstance3D", true, false):
		n.layers = 1
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.355
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(-1.5, -0.02, 0.17), Vector3(0, -0.02, 0.17))   # left side, muzzle to the right
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.resize(768, 256, Image.INTERPOLATE_LANCZOS)
	img.save_png("C:/RTVDev/scar_icon.png")
	print("icon saved")
	get_tree().quit()
