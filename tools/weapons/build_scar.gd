# Builds res://CSWeapons/Model/SCAR_Parts.scn: the FN SCAR-17 model's parts,
# textured (embedded), scaled and turned into the KAR-21 rig's space (barrel
# along +Z, magazine well and muzzle where the KAR-21's are). Each part keeps
# its name; the Weapons Pack mounts them on the KAR-21 rig's bones in game.
# Also renders a side view next to the KAR-21 to C:/RTVDev/scar_preview.png.
extends Node

const SRC := "res://cs_assets/scar/"
const OUT := "res://CSWeapons/Model/"
const SKIP := ["BulletCapsule_Low", "BulletTip_Low"]   # a loose cartridge in the source scene
# Fit: SCAR magazine-well centre and muzzle end -> KAR-21 (z 0.07 and 0.62)
const SCAR_MAG_X := -0.76
const SCAR_MUZZLE_X := 17.73
const SCAR_BORE_Y := 2.05
const KAR_MAG_Z := 0.07
const KAR_MUZZLE_Z := 0.62


func _ready() -> void:
	get_tree().create_timer(200.0).timeout.connect(func(): print("STAGE timeout"); get_tree().quit())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var s := (KAR_MUZZLE_Z - KAR_MAG_Z) / (SCAR_MUZZLE_X - SCAR_MAG_X)
	# SCAR space -> rig space: +X (muzzle) -> +Z, scaled, magazine well at z 0.07, bore at y 0
	var fit := Transform3D(Basis(Vector3.UP, -PI / 2.0).scaled(Vector3.ONE * s), Vector3.ZERO)
	fit.origin = Vector3(0, -SCAR_BORE_Y * s, KAR_MAG_Z) - fit.basis * Vector3(SCAR_MAG_X, 0, 0)
	print("scale ", s)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _tex("DefaultMaterial_Base_Color.jpg", false)
	mat.metallic = 1.0
	mat.metallic_texture = _tex("DefaultMaterial_Metallic.jpg", false)
	mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.roughness = 1.0
	mat.roughness_texture = _tex("DefaultMaterial_Roughness.jpg", false)
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.normal_enabled = true
	mat.normal_texture = _tex("DefaultMaterial_Normal_DirectX.jpg", true)
	mat.ao_enabled = true
	mat.ao_texture = _tex("DefaultMaterial_Mixed_AO.jpg", false)
	var src = load(SRC + "SCAR_straight.fbx").instantiate()
	var root := Node3D.new()
	root.name = "SCAR"
	for m in src.find_children("*", "MeshInstance3D", true, false):
		if m.name in SKIP:
			continue
		var t := Transform3D()
		var x: Node = m
		while x and x != src:
			if x is Node3D:
				t = x.transform * t
			x = x.get_parent()
		var part := MeshInstance3D.new()
		part.name = m.name
		part.mesh = m.mesh.duplicate(true)
		for i in part.mesh.get_surface_count():
			part.mesh.surface_set_material(i, null)
		part.material_override = mat
		part.transform = fit * t
		part.layers = 2                                     # the game draws first-person weapons on layer 2
		root.add_child(part)
		part.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	print("saved ", ResourceSaver.save(ps, OUT + "SCAR_Parts.scn", ResourceSaver.FLAG_COMPRESS))
	await _preview(load(OUT + "SCAR_Parts.scn"))
	get_tree().quit()


func _tex(file: String, normal: bool) -> Texture2D:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + "textures/" + file))
	img.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps()
	img.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_NORMAL if normal else Image.COMPRESS_SOURCE_SRGB)
	return ImageTexture.create_from_image(img)


func _preview(scene: PackedScene) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1400, 600)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.4, 0.42, 0.45)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 60, 0)
	vp.add_child(sun)
	var scar: Node3D = scene.instantiate()
	vp.add_child(scar)
	var kar: Node3D = load("res://Items/Weapons/KAR-21/KAR-21_308_Rig.tscn").instantiate()
	vp.add_child(kar)
	kar.position = Vector3(0, -0.3, 0)                    # below, same scale, for comparison
	for n in kar.find_children("*", "MeshInstance3D", true, false):
		n.layers = 1
		if n.name == "Arms":
			n.visible = false
	for n in scar.find_children("*", "MeshInstance3D", true, false):
		n.layers = 1
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.75
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(1.5, -0.12, 0.2), Vector3(0, -0.12, 0.2))   # from the right side
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png("C:/RTVDev/scar_preview.png")
	print("preview saved")
