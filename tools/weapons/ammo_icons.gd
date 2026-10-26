# Weapons Pack tool: inventory pictures of the new ammo boxes (the game's box
# model wearing each new label), 128x128 like the game's ammo icons.
extends Node

const ART := "C:/Users/greyp/OneDrive/Desktop/Cleanstrike Mod Loader/cleanstrike/mods/WeaponsPack/CSWeaponsPack/Ammo/"
const BOX := "res://Items/Ammo/Ammo_45ACP/Files/MS_Ammo_45ACP.obj"


func _ready() -> void:
	for f in DirAccess.get_files_at(ART):
		if f.ends_with("_Box.png"):
			await _icon(f.trim_suffix("_Box.png"))
	get_tree().quit()


func _icon(art: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.62)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 0.9
	vp.add_child(sun)
	var mi := MeshInstance3D.new()
	mi.mesh = load(BOX)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(ART + art + "_Box.png"))
	mat.roughness = 0.85
	mi.material_override = mat
	vp.add_child(mi)
	var c := mi.get_aabb().get_center()
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.17
	vp.add_child(cam)
	cam.look_at_from_position(c + Vector3(-0.25, 0.7, -0.45).normalized(), c, Vector3(0, 0, -1))
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	img.save_png(ART + art + "_Icon.png")
	print("icon ", art)
	vp.queue_free()
