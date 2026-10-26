extends Node
# Weapons Pack tool: for each base gun, the Attachments bone at rest vs in the
# idle pose, and the vanilla iron-sight height measured from the model.
const BASES := [["SVD", "SVD"], ["KAR-21", "KAR-21_308"], ["Colt_1911", "Colt_1911"], ["MP5", "MP5"], ["AKM", "AKM"], ["Glock_17", "Glock_17"], ["Makarov", "Makarov"], ["MP7", "MP7"], ["AK-12", "AK-12"]]

func _ready() -> void:
	for b in BASES:
		var rig: Node3D = load("res://Items/Weapons/%s/%s_Rig.tscn" % b).instantiate()
		for n in [rig] + rig.find_children("*", "", true, false):
			if n is AnimationTree:
				n.active = false
			if n.get_script() and not (n is AnimationPlayer):
				n.set_script(null)
		add_child(rig)
		var ap: AnimationPlayer = rig.find_children("*", "AnimationPlayer", true, false)[0]
		for a in ap.get_animation_list():
			if a.ends_with("_Idle") and not a.contains("Inspect"):
				ap.play(a)
				ap.seek(0.0, true)
				ap.pause()
		await get_tree().process_frame
		var sk: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0]
		var at: BoneAttachment3D = sk.get_node("Attachments")
		var bi := sk.find_bone(at.bone_name)
		var rest := sk.get_bone_global_rest(bi)
		var pose := sk.get_bone_global_pose(bi)
		var data = load("res://Items/Weapons/%s/%s.tres" % b)
		# muzzle and the highest centreline point within 15 cm behind it (front sight), rest pose, skeleton space
		var refs: BoneAttachment3D = sk.get_node("References")
		var mz: Vector3 = sk.get_bone_global_rest(sk.find_bone(refs.bone_name)) * refs.get_node("Muzzle").position
		var best := Vector3(0, -INF, 0)
		for m in sk.get_children():
			if m is MeshInstance3D and m.mesh and m.name != "Arms" and m.visible:
				for v in m.mesh.get_faces():
					if v.z > mz.z - 0.15 and v.z < mz.z and absf(v.x) < 0.004 and v.y > best.y:
						best = v
		print("%-10s bone %-22s rest %s  idle %s  | aim %.3f  front sight (skel) %.3f -> rest frame %.3f, idle frame %.3f" % [b[1], at.bone_name, rest.origin, pose.origin, -data.aimPosition.y, best.y, (rest.affine_inverse() * best).y, (pose.affine_inverse() * (pose * (rest.affine_inverse() * best))).y])
		rig.queue_free()
	get_tree().quit()
