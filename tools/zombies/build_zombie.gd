# Builds res://CSZombies/Model/Zombie.tscn: the zombie model (metres, Y up,
# textured), one AnimationPlayer with every clip (the zombie's own and the
# Mixamo ones, all retargeted to the humanoid profile at import), then renders
# preview frames to C:/RTVDev/zombie_preview/.
extends Node

const SRC := "res://cs_assets/zombies/"
const OUT := "res://CSZombies/Model/"
const PREVIEW := "C:/RTVDev/zombie_preview/"

# clip name -> source file (Mixamo packs a and b, and the model's own)
const CLIPS := {
	"idle": "mixamo_b/zombie_idle.fbx", "idle_2": "mixamo_a/zombie_idle_2.fbx", "idle_3": "mixamo_a/zombie_idle_3.fbx",
	"idle_scratch": "mixamo_a/zombie_scratch_idle.fbx", "agonizing": "mixamo_a/zombie_agonizing.fbx",
	"walk": "mixamo_b/zombie_walk.fbx", "walk_2": "mixamo_a/walking.fbx", "walk_3": "mixamo_a/walking_2.fbx",
	"stumble": "mixamo_a/zombie_stumbling.fbx", "run": "mixamo_b/zombie_run.fbx", "run_2": "mixamo_a/zombie_running.fbx",
	"turn": "mixamo_a/zombie_turn.fbx", "scream": "mixamo_b/zombie_scream.fbx",
	"attack": "mixamo_b/zombie_attack.fbx", "attack_2": "mixamo_a/zombie_attack.fbx", "punch": "mixamo_a/zombie_punching.fbx",
	"punch_2": "mixamo_a/zombie_punching_2.fbx", "headbutt": "mixamo_a/zombie_headbutt.fbx", "kick": "mixamo_a/zombie_kicking.fbx",
	"bite": "mixamo_b/zombie_biting.fbx", "bite_2": "mixamo_b/zombie_biting_2.fbx", "neck_bite": "mixamo_b/zombie_neck_bite.fbx",
	"hit": "mixamo_a/zombie_reaction_hit.fbx", "hit_2": "mixamo_a/zombie_reaction_hit_2.fbx",
	"death": "mixamo_b/zombie_death.fbx", "dying": "mixamo_b/zombie_dying.fbx",
	"stand_up": "mixamo_a/zombie_stand_up.fbx", "stand_up_2": "mixamo_a/zombie_stand_up_2.fbx",
	"crawl": "mixamo_b/zombie_crawl.fbx", "crawl_run": "mixamo_b/running_crawl.fbx",
	"transition": "mixamo_a/zombie_transition.fbx",
}
const LOOPS := ["idle", "idle_2", "idle_3", "idle_scratch", "walk", "walk_2", "walk_3", "stumble", "run", "run_2", "crawl", "crawl_run", "agonizing"]
const SHOW := [["idle", 0.5], ["walk", 0.4], ["run", 0.3], ["attack", 0.6], ["crawl", 0.5], ["death", 2.5], ["scream", 1.0], ["bite", 0.8]]


func _ready() -> void:
	get_tree().create_timer(280.0).timeout.connect(func(): print("STAGE timeout"); get_tree().quit())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.make_dir_recursive_absolute(PREVIEW)
	var lib := AnimationLibrary.new()
	for clip in CLIPS:
		var src = load(SRC + CLIPS[clip]).instantiate()
		var ap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
		var anim: Animation = ap.get_animation(ap.get_animation_list()[0]).duplicate(true)
		anim.loop_mode = Animation.LOOP_LINEAR if clip in LOOPS else Animation.LOOP_NONE
		_root_motion_off(anim)
		lib.add_animation(clip, anim)
		src.free()
		print("clip ", clip, " ", snappedf(anim.length, 0.01), "s")

	var model = load(SRC + "model/Zombie1.FBX").instantiate()
	model.name = "Zombie"
	var old_ap = model.get_node_or_null("AnimationPlayer")
	if old_ap:
		old_ap.free()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _portable("Zombie.png", false)
	mat.normal_enabled = true
	mat.normal_texture = _portable("Zombie_nm.png", true)
	mat.ao_enabled = true
	mat.ao_texture = _portable("Zombie_ao.png", false)
	mat.roughness = 0.85
	mat.emission_enabled = false   # the eyes texture alone; full glow off for now
	mat.emission_texture = _portable("zombie_emission.png", false)
	mat.emission = Color(1, 1, 1)
	mat.emission_energy_multiplier = 1.5
	print("STAGE local ", Time.get_ticks_msec())
	model.scene_file_path = ""
	for n in model.find_children("*", "", true, false):
		n.scene_file_path = ""
		n.owner = model
	for m in model.find_children("*", "MeshInstance3D", true, false):
		m.mesh = m.mesh.duplicate(true)
		m.mesh.surface_set_material(0, null)
		if m.skin:
			m.skin = m.skin.duplicate(true)
		m.material_override = mat
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	model.add_child(ap)
	ap.owner = model
	ap.add_animation_library("", lib)
	print("STAGE saving ", Time.get_ticks_msec())
	var err := ResourceSaver.save(_pack(model), OUT + "Zombie.scn", ResourceSaver.FLAG_COMPRESS)
	print("saved ", OUT + "Zombie.scn ", err)
	await _preview(load(OUT + "Zombie.scn"))
	get_tree().quit()


# Keep the hips over the origin sideways (the game moves the body).
func _root_motion_off(anim: Animation) -> void:
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and str(anim.track_get_path(t)).ends_with(":Hips"):
			for k in anim.track_get_key_count(t):
				var v: Vector3 = anim.track_get_key_value(t, k)
				anim.track_set_key_value(t, k, Vector3(0, v.y, 0) if not anim.has_meta("keep_xz") else v)


func _pack(n: Node) -> PackedScene:
	for c in n.find_children("*", "", true, false):
		if c.owner == null:
			c.owner = n
	var ps := PackedScene.new()
	ps.pack(n)
	return ps


func _preview(scene: PackedScene) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 512)
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.35, 0.37, 0.4)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.5)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	vp.add_child(sun)
	var z: Node3D = scene.instantiate()
	vp.add_child(z)
	var box := AABB()
	var first := true
	for m in z.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	print("model bounds ", box)
	var m0: MeshInstance3D = z.find_children("*", "MeshInstance3D", true, false)[0]
	print("mesh0 override ", m0.material_override, " surf ", m0.mesh.surface_get_material(0), " skin ", m0.skin != null, " global scale ", m0.global_transform.basis.get_scale())
	var cam := Camera3D.new()
	vp.add_child(cam)
	var c := box.get_center()
	var h := maxf(box.size.y, maxf(box.size.x, box.size.z))
	cam.look_at_from_position(c + Vector3(0.6, 0.15, 1.0).normalized() * h * 1.8, c)
	var ap: AnimationPlayer = z.get_node("AnimationPlayer")
	for s in SHOW:
		ap.play(s[0])
		ap.seek(s[1], true)
		ap.pause()
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(PREVIEW + "%s.png" % s[0])
		print("preview ", s[0])


# A texture that lives inside the saved scene (no import needed in the game).
func _portable(file: String, normal: bool) -> Texture2D:
	print("STAGE texture ", file, " ", Time.get_ticks_msec())
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + "textures/" + file))
	img.generate_mipmaps()
	if normal:
		img.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_NORMAL)
	else:
		img.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_SRGB)
	var t := ImageTexture.create_from_image(img)   # embedded, block-compressed
	return t
