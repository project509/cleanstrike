extends SceneTree

func _init() -> void:
	for path in ["res://cs_assets/zombies/model/Zombie1.FBX", "res://cs_assets/zombies/mixamo_a/zombie_attack.fbx", "res://cs_assets/zombies/model/Zombie@Z_Walk.FBX"]:
		var ps = load(path)
		if ps == null:
			print("FAILED ", path)
			continue
		var n = ps.instantiate()
		print("== ", path)
		for sk in n.find_children("*", "Skeleton3D", true, false):
			var names := []
			for i in sk.get_bone_count():
				names.append(sk.get_bone_name(i))
			print("skeleton ", sk.name, " bones ", sk.get_bone_count(), ": ", ", ".join(names))
		for m in n.find_children("*", "MeshInstance3D", true, false):
			print("mesh ", m.name, " aabb ", m.get_aabb(), " surfaces ", m.mesh.get_surface_count() if m.mesh else 0)
		for ap in n.find_children("*", "AnimationPlayer", true, false):
			for a in ap.get_animation_list():
				print("anim ", a, " len ", ap.get_animation(a).length, " tracks ", ap.get_animation(a).get_track_count())
	quit()
