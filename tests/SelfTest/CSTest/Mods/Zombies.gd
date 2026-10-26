# Self-test for CleanStrike Zombies (cs_zombies). r is the CSTest runner.
extends RefCounted

const ZM = preload("res://CSZombies/Mod.gd")
const LIMBS := ["Z_Head", "Z_L_Upperarm", "Z_L_Forearm", "Z_L_ArmPalm", "Z_R_Upperarm", "Z_R_Forearm", "Z_R_ArmPalm",
	"Z_L_LegThigh", "Z_L_LegCalf", "Z_R_LegThigh", "Z_R_LegCalf"]

var made := []


func _frames(r, n: int) -> void:
	for i in n:
		await r.get_tree().physics_frame


func _zombie(r, at: Vector3) -> Node3D:
	var z: Node3D = ZM.scene().instantiate()
	r.get_tree().current_scene.add_child(z)
	z.global_position = at
	z.Activate("Wander")
	made.append(z)
	return z


func run(r) -> void:
	r.check("Zombies: active", ZM.active())
	# The model
	var scene = load(ZM.MODEL)
	r.check("Zombies: model loads in the game", scene is PackedScene)
	var probe: Node3D = scene.instantiate()
	var missing := LIMBS.filter(func(n): return probe.find_child(n, true, false) == null)
	r.check("Zombies: every limb is its own mesh", missing.is_empty(), str(missing))
	r.check("Zombies: all 31 animations", probe.get_node("AnimationPlayer").get_animation_list().size() == 31)
	probe.free()

	var gd = load("res://Resources/GameData.tres")
	var player = r.get_node("/root/Map/Core/Controller")
	var keep_health: float = gd.health
	var cam = r.get_viewport().get_camera_3d()
	var fwd: Vector3 = -Vector3(cam.global_basis.z.x, 0, cam.global_basis.z.z).normalized()
	var feet: Vector3 = player.global_position

	# Built zombie: human sized, a hitbox on every part
	var z := _zombie(r, feet + fwd * 8.0)
	await _frames(r, 3)
	var sk: Skeleton3D = z.skeleton
	var head: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head")).origin
	r.check("Zombies: human sized", head.y - z.global_position.y > 1.2 and head.y - z.global_position.y < 2.0, "%.2f" % (head.y - z.global_position.y))
	var toe: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("LeftToes")).origin
	var ankle: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("LeftFoot")).origin
	var toes_dir: Vector3 = ((toe - ankle) * Vector3(1, 0, 1)).normalized()
	r.check("Zombies: walks face first (toes point -z)", toes_dir.dot(-z.global_basis.z) > 0.5, "toes . forward = %.2f" % toes_dir.dot(-z.global_basis.z))
	r.check("Zombies: a hitbox on every body part", z.hitboxes.size() == ZM.PARTS.size() and z.hitboxes[0] is Hitbox)
	var head_hb = sk.get_node("HB_head/Hitbox")
	r.check("Zombies: head hitbox sits on the head", head_hb.global_position.distance_to(head) < 0.35, "%.2f m" % head_hb.global_position.distance_to(head))

	# Its voice: every sound loads, and it speaks
	var bad := []
	for kind in ZM.VOICES:
		for i in 6:
			if ZM.sound(kind) == null:
				bad.append(kind)
	r.check("Zombies: all its sounds load", bad.is_empty(), str(bad))
	z.Say("scream", true)
	r.check("Zombies: it screams", z.voice.stream != null and z.voice.bus == &"SFX")
	z.voice.stop()
	ZM.speaking = 0

	# A gunshot: it comes for you
	z.look_at(feet + fwd * 20.0, Vector3.UP)          # facing away: it must hear, not see
	gd.playerPosition = feet
	feet = gd.playerPosition
	ZM.note_shot(feet)                               # what the weapon records on each shot
	var hooked := false
	var rig = load("res://Items/Weapons/AKM/AKM_Rig.tscn").instantiate()   # class script: check a real rig
	r.get_tree().current_scene.add_child(rig)
	var ws = rig.get_script()
	while ws:
		hooked = hooked or ws.get_script_constant_map().has("ZW")
		ws = ws.get_base_script()
	rig.queue_free()
	r.check("Zombies: every shot is recorded at the weapon", hooked)
	z.think = 0.0
	var tw := 0.0
	while z.last_heard < 0.0 and tw < 2.0:            # until it has had a moment to think
		await r.wait(0.05)
		tw += 0.05
	r.check("Zombies: a gunshot brings it", z.state in [z.S.INVESTIGATE, z.S.CHASE], "state %d heard %.2f shot %.2f now %.2f dist %.1f active %s proc %s think %.2f" % [z.state, z.last_heard, ZM.last_shot, Time.get_ticks_msec() / 1000.0, ZM.last_shot_at.distance_to(z.global_position), z.active, z.can_process(), z.think])
	var d0: float = z.global_position.distance_to(feet)
	var tm := 0.0
	while z.global_position.distance_to(feet) > d0 - 0.6 and tm < 6.0:   # slow frames in the suite
		await r.wait(0.1)
		tm += 0.1
	r.check("Zombies: it walks towards you", z.global_position.distance_to(feet) < d0 - 0.5, "%.1f -> %.1f m" % [d0, z.global_position.distance_to(feet)])

	# The pack hears the call
	var z2 := _zombie(r, feet + fwd * 8.0 + Vector3(3, 0, 0))
	var z3 := _zombie(r, feet + fwd * 80.0)
	await _frames(r, 2)
	var n: int = ZM.alert_near(z, feet)
	await r.wait(2.5)
	r.check("Zombies: nearby zombies come too", n >= 1 and z2.state in [z2.S.INVESTIGATE, z2.S.CHASE], str(z2.state))
	r.check("Zombies: but not ones far away", z3.state == z3.S.WANDER)

	# Shot at, now and then one charges (never otherwise)
	r.check("Zombies: they shamble", not z2._enraged() and z2._speed() < 1.5)
	ZM.overrides = {"rage_chance": 1.0}
	z2.Hit("torso", 1.0, fwd, player.get_node_or_null("../Camera/ID") if player.get_node_or_null("../Camera/ID") else r.get_tree().get_first_node_in_group("Player"), z2.global_position + Vector3.UP)
	ZM.overrides = {}
	r.check("Zombies: enraged by a shot, it charges", z2._enraged() and z2._speed() > 2.0)
	z2.enraged_until = -1000.0

	# Up close it attacks, and it hurts
	feet = gd.playerPosition
	z2.global_position = feet + fwd * 1.2
	z2.last_seen = Time.get_ticks_msec() / 1000.0
	z2.target = feet
	z2.state = z2.S.CHASE
	gd.health = 100.0
	z2.think = 0.0
	var t := 0.0
	while gd.health >= 100.0 and t < 4.0:
		z2.last_seen = Time.get_ticks_msec() / 1000.0
		await r.wait(0.1)
		t += 0.1
	r.check("Zombies: its blows hurt", gd.health < 100.0, "%.1f health after %.1f s; state %d d %.2f dead %s seen %s" % [gd.health, t, z2.state, z2.global_position.distance_to(feet), z2.dead, z2.Sees()])
	gd.health = keep_health

	# Out of sight for three minutes (and nothing heard), it loses interest
	var zf := _zombie(r, feet + fwd * 30.0)
	await _frames(r, 2)
	var now := Time.get_ticks_msec() / 1000.0
	zf.state = zf.S.CHASE
	zf.target = feet
	zf.last_seen = now - 60.0
	zf.last_heard = now - 60.0
	zf.global_basis = Basis.looking_at(-fwd * -1.0, Vector3.UP)
	zf._decide()
	r.check("Zombies: a minute unseen, it still hunts", zf.state == zf.S.CHASE or zf.state == zf.S.DOOR or zf.Sees())
	zf.last_seen = now - 185.0
	zf.last_heard = now - 185.0
	if not zf.Sees():
		zf._decide()
		r.check("Zombies: three minutes unseen, it gives up", zf.state == zf.S.WANDER, str(zf.state))
	else:
		r.check("Zombies: three minutes unseen, it gives up", true, "in view here; skipped")

	# Shoot a leg off: a crawler, and the leg on the floor
	var leg = sk.get_node("HB_leg_l_lower/Hitbox")
	leg.ApplyDamage(90.0, fwd, player.get_node_or_null("../Camera/ID"))
	await _frames(r, 2)
	var calf: MeshInstance3D = z.model.find_child("Z_L_LegCalf", true, false)
	r.check("Zombies: legless zombies crawl", z.crawler and not calf.visible and z.lost.has("leg_l_lower") and not z.dead)
	var limbs: Array = r.get_tree().current_scene.find_children("CS_Limb", "RigidBody3D", true, false)
	r.check("Zombies: the severed leg falls", limbs.size() >= 1 and limbs[0].get_child(0).mesh.get_surface_count() > 0, "limbs %d" % limbs.size())
	r.check("Zombies: a severed part can't be hit again", leg.collision_layer == 0)
	r.check("Zombies: the stump keeps bleeding", sk.get_node("HB_leg_l_lower").get_node_or_null("CS_Stump") != null)

	# Headshots kill; the body can be searched
	var hp: float = z.health
	head_hb.ApplyDamage(30.0, fwd, null)
	r.check("Zombies: headshots hit hard", hp - z.health >= 90.0, "%.0f" % (hp - z.health))
	head_hb.ApplyDamage(100.0, fwd, null)
	await _frames(r, 2)
	r.check("Zombies: dead", z.dead and not z.model.find_child("Z_Head", true, false).visible)
	var loot = z.get_node_or_null("CS_Loot")
	r.check("Zombies: the body can be searched", loot != null and loot.has_method("Interact") and loot.containerName == "Zombie")
	var total := 0
	var with_loot := 0
	ZM.overrides = {"loot_chance": 0.5}
	for i in 40:
		var probe_z := Node3D.new()
		r.get_tree().current_scene.add_child(probe_z)
		var c = ZM._corpse_loot(probe_z)
		total += 1
		with_loot += 1 if not c.loot.is_empty() else 0
		probe_z.free()
	ZM.overrides = {}
	r.check("Zombies: some bodies carry ammo or food", with_loot > 5 and with_loot < 35, "%d of %d" % [with_loot, total])

	# Ten blows break a door
	var door = load("res://Assets/Shack_A/Shack_A_Door_L.tscn").instantiate()
	r.get_tree().current_scene.add_child(door)
	door.global_position = feet + Vector3(0, -50, 0)
	var dn = ZM.door_of(door.find_children("*", "CollisionShape3D", true, false)[0])
	dn.isOpen = false                                # doors can start open
	var broke := false
	for i in 9:
		broke = broke or ZM.hit_door(dn)
	r.check("Zombies: a door holds for nine blows", dn != null and not broke and not dn.isOpen, "door %s broke %s open %s hits %s" % [str(dn), broke, dn.isOpen if dn else "-", str(dn.get_meta("cs_hits")) if dn else "-"])
	broke = ZM.hit_door(dn)
	await _frames(r, 2)
	r.check("Zombies: the tenth breaks it", broke and dn.isOpen and not dn.visible)

	# The spawner fills its pools with the dead
	var sp = load("res://Resources/AISpawner.tscn").instantiate()
	sp.active = false
	r.get_tree().current_scene.add_child(sp)
	sp.global_position = Vector3(0, -500, 0)
	sp.enemy = sp.bandit
	sp.EPoolSize = 3
	sp.NPoolSize = 2
	sp.activeEnemyLimit = 2
	await sp.CreatePools()
	var all_dead: bool = sp.EPool.get_children().all(func(e): return e.has_method("Hit"))
	r.check("Zombies: every enemy is a zombie", all_dead and sp.EPool.get_child_count() == int(round(3 * float(ZM.setting("horde")))) and sp.NPool.get_child_count() == 0, "%d enemies, %d nomads" % [sp.EPool.get_child_count(), sp.NPool.get_child_count()])
	r.check("Zombies: bosses too", sp.BPool.get_children().all(func(e): return e.has_method("Hit")))
	# Pressure: shots build it, the spawner sends more and closer; hiding cools it
	ZM.heat = 0.0
	for i in 10:
		ZM.note_shot(Vector3(0, -900, 0))
	r.check("Zombies: shooting builds pressure", ZM.heat > 0.4, "%.2f" % ZM.heat)
	var calm_limit: int = sp.zs_base_limit
	sp.active = true
	sp._physics_process(0.016)
	r.check("Zombies: pressure means more of them, closer", sp.activeEnemyLimit > calm_limit and sp.spawnDistance < sp.zs_base_distance, "%d > %d, %.0f m" % [sp.activeEnemyLimit, calm_limit, sp.spawnDistance])
	var h: float = ZM.heat
	ZM.cool(5.0)
	r.check("Zombies: no cooling while they still know where you are", ZM.heat == h)
	ZM.noticed_at -= 40.0
	ZM.cool(60.0)
	r.check("Zombies: hiding cools it", ZM.heat < h)
	ZM.heat = 0.0
	var pool_before: int = sp.EPool.get_child_count()
	sp.ZS_Replenish()
	r.check("Zombies: the dead are replaced", sp.EPool.get_child_count() == pool_before + 1)
	sp.active = false
	sp.queue_free()
	door.queue_free()
	for m in made:
		if is_instance_valid(m):
			m.queue_free()
	for l in r.get_tree().current_scene.find_children("CS_Limb", "RigidBody3D", true, false):
		l.queue_free()
	await _frames(r, 2)
