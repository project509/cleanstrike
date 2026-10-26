# Self-test for CleanStrike Weapons Pack (cs_weapons_pack). r is the CSTest runner.
extends RefCounted

const WP = preload("res://CSWeaponsPack/Mod.gd")
const G = preload("res://CSWeaponsPack/Guns.gd")


func run(r) -> void:
	r.check("WeaponsPack: active", WP.active())
	var db = r.get_node("/root/Database")
	var lt = load("res://Loot/LT_Master.tres")
	for id in G.guns():
		await _gun(r, db, lt, id, G.guns()[id])
	for aid in G.ammo():
		var a = WP.items.get(aid)
		if a == null:
			continue
		r.check("WeaponsPack: %s: an ammo box like the game's, sold and found" % aid, a.type == "Ammo" and a.stackable and a.icon != null and db.get(aid) is PackedScene and lt.items.has(a) and a.gunsmith)


func _gun(r, db, lt, id: String, g: Dictionary) -> void:
	var tag := "WeaponsPack: " + id + ": "
	var d = WP.items.get(g.file)
	r.check(tag + "built", d != null and db.get(g.file) is PackedScene and db.get(g.file + "_Rig") is PackedScene)
	if d == null:
		return
	var base = load(WP.base_path(g, ".tres"))
	# the rig: the base gun's arms and animations, this gun's parts on its bones
	var rig: Node3D = db.get(g.file + "_Rig").instantiate()
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	r.get_tree().current_scene.add_child(rig)
	rig.global_position = Vector3(0, -600, 0)
	var sk: Skeleton3D = rig.get("skeleton")
	var vanilla := sk.get_children().filter(func(m): return m is MeshInstance3D and m != rig.get("arms") and m.mesh != null)
	r.check(tag + "the base gun's model is gone, the arms stay", vanilla.is_empty() and rig.get("arms").visible, str(vanilla.map(func(m): return m.name)))
	var mag_node: Node = rig.get("magazine")
	r.check(tag + "the rig shows and hides this gun's magazine", mag_node != null and mag_node.name == "CS_Magazine" and mag_node.get_parent() is BoneAttachment3D and str(mag_node.get_parent().bone_name).contains("Magazine"))
	var trig = rig.find_child("CS_Trigger", true, false)
	if trig:                                       # (some models have the trigger fused to the frame)
		r.check(tag + "trigger on the trigger bone", str(trig.get_parent().bone_name).ends_with("_Trigger"))
	if rig.get("dynamicSlide") and rig.find_child("CS_Slide", true, false):
		r.check(tag + "slide on the slide bone", rig.find_child("CS_Slide", true, false).get_parent().bone_name == sk.get_bone_name(rig.get("slideIndex")))
	var parts: Node = load(WP.DIR + id + "/Parts.scn").instantiate()
	var L: Dictionary = parts.get_meta("landmarks")
	parts.free()
	var muzzle: Node3D = rig.get("muzzle")
	var local_muzzle: Vector3 = sk.global_transform.affine_inverse() * muzzle.global_position
	r.check(tag + "muzzle flash at this gun's muzzle", local_muzzle.distance_to(L.muzzle) < 0.02, str(local_muzzle) + " vs " + str(L.muzzle))
	r.check(tag + "the game's weapon rig, carrying this gun's data", rig.has_method("FireEvent") and rig.get("data") == d)
	if g.get("fold", false):
		r.check(tag + "flip-up sights fold the game's way", d.foldSights and sk.get_bone_name(rig.get("backSightIndex")) == "CS_Sight_Rear" and sk.get_bone_name(rig.get("frontSightIndex")) == "CS_Sight_Front")
	# its own touches after a shot
	var fx := Node3D.new()
	muzzle.add_child(fx)
	WP.on_fire(rig)
	r.check(tag + "its own muzzle flash size", is_equal_approx(fx.scale.x, g.get("feel", {}).get("flash", 1.0)))
	rig.queue_free()
	# the item
	var mag = d.compatible[0]
	r.check(tag + "its own name, icon and magazine", d.file == g.file and d.name == g.name and d.icon != null and mag.subtype == "Magazine" and d.magazineSize == mag.maxAmount)
	r.check(tag + "takes its ammo", mag.compatible.has(d.ammo) and (g.get("data", {}).get("caliber", base.caliber) == d.caliber))
	var aim_z: float = base.aimPosition.z + g.get("shift", {}).get("aimPosition", Vector3.ZERO).z
	r.check(tag + "aims through its own sights", is_equal_approx(d.aimPosition.z, aim_z) and d.aimPosition.y < 0.0)
	var pitch: float = g.get("feel", {}).get("pitch", 1.0)
	var voice_src = base.fireSemi
	if g.has("voice") and g.voice.has("fireSemi") and g.voice.fireSemi is String:
		voice_src = load(g.get("voice_from", WP.base_path(g, ".tres"))).get(g.voice.fireSemi)
	if pitch != 1.0 and voice_src and not g.has("energy"):
		r.check(tag + "its own voice", d.fireSemi.audioClips[0].mix_rate == int(voice_src.audioClips[0].mix_rate * pitch))
	r.check(tag + "found in loot, and sold where its base gun is", lt.items.has(d) and d.gunsmith == g.get("data", {}).get("gunsmith", base.gunsmith))
	if g.magazine is Dictionary:
		r.check(tag + "its magazine is an item like the game's", WP.items.has(mag.file) and db.get(mag.file) is PackedScene and lt.items.has(mag) and mag.icon != null)
	var t: Node = d.tetris.instantiate()
	r.check(tag + "inventory picture shows its magazine when loaded", t.has_node(NodePath(str(mag.file))))
	t.free()
	# lying in the world
	var pk = db.get(g.file).instantiate()
	r.get_tree().current_scene.add_child(pk)
	pk.global_position = Vector3(0, -620, 0)
	r.check(tag + "on the ground it is this gun", pk is Pickup and pk.slotData.itemData == d and pk.get_node("LOD0").mesh is ArrayMesh and pk.has_node("Attachments/" + str(mag.file)))
	pk.queue_free()
	# saved, loaded, fired
	var sd := SlotData.new()
	sd.itemData = d
	sd.amount = 5
	sd.chamber = true
	sd.condition = 100
	var path := "user://cs_wp_test.tres"
	ResourceSaver.save(sd, path)
	var back = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	r.check(tag + "saves and loads", back.itemData.file == g.file and back.amount == 5)
	var fr = db.get(back.itemData.file + "_Rig").instantiate()
	fr.process_mode = Node.PROCESS_MODE_DISABLED
	r.get_tree().current_scene.add_child(fr)
	fr.slotData = back
	fr.fireTimer = 1.0
	var zl = load("res://CSZombies/Mod.gd") if WP.cs() and WP.cs().is_loaded("cs_zombies") else null
	if zl:
		zl.last_shot = -1000.0
	fr.FireEvent()
	if d.has_meta("cs_energy"):
		var bolt = r.get_tree().current_scene.find_child("CS_RayBolt", true, false)
		r.check(tag + "an energy bolt leaves the muzzle", bolt != null and bolt.find_children("*", "GPUParticles3D", true, false).size() >= 2 and d.casing == 0)
	if d.has_meta("cs_bolt"):
		r.check(tag + "bolt action: the shot leaves the chamber empty, the next round in the magazine", not back.chamber and back.amount == 5)
	else:
		r.check(tag + "fires: a round used", back.amount == 4)
	if zl:
		if g.get("silent", false):
			r.check(tag + "silent: the zombies never hear it", zl.last_shot == -1000.0 and d.nativeSuppressor)
		else:
			r.check(tag + "the zombies hear it", zl.last_shot > -1000.0)
	if g.has("head_damage"):
		r.check(tag + "its own headshot", is_equal_approx(float(d.get_meta("cs_head_damage", 0.0)), float(g.head_damage)))
	if g.get("bolt", false):
		r.check(tag + "weak to the body", d.damage < base.damage)
	fr.queue_free()
	await r.get_tree().process_frame
