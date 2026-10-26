# Self-test for CleanStrike Zombies (cs_zombies). r is the CSTest runner.
extends RefCounted

const ZM = preload("res://CSZombies/Mod.gd")
const LIMBS := ["Z_Head", "Z_L_Upperarm", "Z_L_Forearm", "Z_L_ArmPalm", "Z_R_Upperarm", "Z_R_Forearm", "Z_R_ArmPalm",
	"Z_L_LegThigh", "Z_L_LegCalf", "Z_R_LegThigh", "Z_R_LegCalf"]


func run(r) -> void:
	r.check("Zombies: active", ZM.active())
	var scene = load(ZM.MODEL)
	r.check("Zombies: model loads in the game", scene is PackedScene)
	if not (scene is PackedScene):
		return
	var z: Node3D = scene.instantiate()
	r.get_tree().current_scene.add_child(z)
	z.global_position = Vector3(0, -300, 0)
	var sk: Skeleton3D = z.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = z.get_node("AnimationPlayer")
	var missing := LIMBS.filter(func(n): return z.find_child(n, true, false) == null)
	r.check("Zombies: every limb is its own mesh", missing.is_empty(), str(missing))
	var clips := ap.get_animation_list()
	r.check("Zombies: all 31 animations", clips.size() == 31 and clips.has("walk") and clips.has("crawl") and clips.has("attack"), str(clips.size()))
	ap.play("idle")
	ap.advance(0.5)
	await r.get_tree().process_frame
	var head: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head")).origin
	var foot: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("LeftFoot")).origin
	var height := head.y - foot.y
	r.check("Zombies: human sized", height > 1.2 and height < 2.0, "%.2f m head above feet" % height)
	var mat: StandardMaterial3D = (z.find_child("Z_Body", true, false) as MeshInstance3D).material_override
	r.check("Zombies: textured", mat != null and mat.albedo_texture != null and mat.albedo_texture.get_width() == 1024)
	ap.play("crawl")
	ap.advance(0.5)
	await r.get_tree().process_frame
	var hips: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hips")).origin
	r.check("Zombies: crawling is low", hips.y - z.global_position.y < 0.6, "%.2f m" % (hips.y - z.global_position.y))
	z.queue_free()
