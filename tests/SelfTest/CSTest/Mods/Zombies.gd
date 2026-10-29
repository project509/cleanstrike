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

	# Built like the game's enemies: the same solid body and navigation agent
	var ours: SceneState = ZM.scene().get_state()
	var theirs: SceneState = load("res://AI/Bandit/AI_Bandit.tscn").get_state()
	var same := []
	for n in ["Collision", "Collision/Shape", "Agent"]:
		var a := _props(ours, n)
		var b := _props(theirs, n)
		for k in ["collision_layer", "collision_mask", "transform", "path_desired_distance", "path_height_offset", "navigation_layers"]:
			if a.get(k) != b.get(k):
				same.append("%s.%s %s vs %s" % [n, k, str(a.get(k)), str(b.get(k))])
		if b.has("shape") and (a.get("shape") == null or a.shape.radius != b.shape.radius or a.shape.height != b.shape.height):
			same.append(n + ".shape")
	r.check("Zombies: body and navigation agent as the game's enemies", same.is_empty(), str(same))
	r.check("Zombies: the body blocks the player, not bullets or sight", int(_props(ours, "Collision").collision_layer) & (93 | z.SIGHT_MASK | z.GROUND_MASK | z.PROBE_MASK) == 0)

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
	r.check("Zombies: a gunshot brings it", z.state in [z.S.INVESTIGATE, z.S.CHASE], "state %d heard %.2f shot %.2f now %.2f dist %.1f active %s proc %s think %.2f" % [z.state, z.last_heard, ZM.last_shot, z._now(), ZM.last_shot_at.distance_to(z.global_position), z.active, z.can_process(), z.think])
	r.check("Zombies: it heads for the sound", z.target.distance_to(feet) < 1.0 and z._hunting(), "target %.1f m off" % z.target.distance_to(feet))
	# The Tutorial has no navigation mesh: like the game's enemies, it stands
	# rather than walk straight through whatever is in the way.
	var nav_here: bool = NavigationServer3D.map_get_closest_point(z._map(), feet) != Vector3.ZERO
	var p0: Vector3 = z.global_position
	await _frames(r, 60)
	if nav_here:
		r.check("Zombies: it walks towards you", z.global_position.distance_to(feet) < p0.distance_to(feet) - 0.3)
	else:
		r.check("Zombies: no navigation mesh, no beeline through walls", z.global_position.distance_to(p0) < 0.05, "%.2f m" % z.global_position.distance_to(p0))

	# The pack hears the call (from calm: earlier gunfire in the suite raises the swarm's heat)
	ZM.heat = 0.0
	var z2 := _zombie(r, feet + fwd * 8.0 + Vector3(3, 0, 0))
	var z3 := _zombie(r, feet + fwd * 80.0)
	await _frames(r, 2)
	var n: int = ZM.alert_near(z, feet)
	var ta := 0.0
	while z2.state == z2.S.WANDER and ta < 4.0:     # the call reaches them within 1.8 s
		await r.wait(0.1)
		ta += 0.1
	r.check("Zombies: nearby zombies come too", n >= 1 and z2.state in [z2.S.INVESTIGATE, z2.S.CHASE], "n %d state %d target %.1f m off, %.1f m away, path %d, heard %.1f s ago" % [n, z2.state, z2.target.distance_to(feet), z2.global_position.distance_to(feet), z2.agent.get_current_navigation_path().size(), z2._now() - z2.last_heard])
	r.check("Zombies: but not ones far away", z3.state == z3.S.WANDER)

	# Shot at, now and then one charges (never otherwise)
	r.check("Zombies: wanderers shamble", z3.state == z3.S.WANDER and z3._speed() > 0.35 and z3._speed() < 0.75, "%.2f m/s" % z3._speed())
	z2.state = z2.S.CHASE
	z2.last_seen = z2._now()
	var hunt: float = z2._speed()
	r.check("Zombies: hunters come at a brisk pace (25% slower than 1.1.2)", not z2._enraged() and hunt > 1.25 and hunt < 1.95, "%.2f m/s" % hunt)
	ZM.overrides = {"rage_chance": 1.0}
	z2.Hit("torso", 1.0, fwd, player.get_node_or_null("../Camera/ID") if player.get_node_or_null("../Camera/ID") else r.get_tree().get_first_node_in_group("Player"), z2.global_position + Vector3.UP)
	ZM.overrides = {}
	r.check("Zombies: enraged by a shot, it sprints", z2._enraged() and z2._speed() > 2.1 and z2._speed() < 3.2, "%.2f m/s" % z2._speed())
	z2.enraged_until = -1000.0

	# Up close it attacks, and it hurts
	feet = gd.playerPosition
	z2.global_position = feet + fwd * 1.2
	z2.last_seen = z2._now()
	z2.target = feet
	z2.state = z2.S.CHASE
	gd.health = 100.0
	z2.think = 0.0
	var t := 0.0
	while gd.health >= 100.0 and t < 4.0:
		z2.last_seen = z2._now()
		if z2.state != z2.S.ATTACK and z2.global_position.distance_to(gd.playerPosition) > 1.5:
			z2.global_position = gd.playerPosition + fwd * 1.2     # the player settling: keep it in reach
		await r.wait(0.1)
		t += 0.1
	r.check("Zombies: its blows hurt", gd.health < 100.0, "%.1f health after %.1f s; state %d d %.2f dead %s seen %s; you dead %s at %.2f m; %s busy %s" % [gd.health, t, z2.state, z2.global_position.distance_to(feet), z2.dead, z2.Sees(), gd.isDead, z2.global_position.distance_to(gd.playerPosition), z2.current_anim, z2._busy()])
	gd.health = keep_health

	# Ten seconds with the line of sight broken, it loses you; a glimpse starts the count again
	r.check("Zombies: loses you after 10 s out of sight (default)", float(ZM.setting("aggro_seconds")) == 10.0 and float(ZM.DEFAULTS.aggro_seconds) == 10.0)
	var zf := _zombie(r, feet + fwd * 30.0)
	await _frames(r, 2)
	zf.active = false                                # driven by hand: its clock and its senses
	zf.state = zf.S.CHASE
	zf.target = feet
	zf.last_seen = zf._now()
	zf.last_heard = zf._now()
	ZM.overrides = {"sight": 0.1}                    # nothing in view: the line of sight is broken
	zf.clock += 9.0
	zf._decide()
	r.check("Zombies: 9 s out of sight, it still hunts", zf.state in [zf.S.CHASE, zf.S.DOOR, zf.S.ATTACK] and zf.target.distance_to(gd.playerPosition) < 0.5, str(zf.state))
	ZM.overrides = {}
	zf.global_position = gd.playerPosition + fwd * 2.6           # in plain view
	var glimpse: bool = zf.Sees()
	zf._decide()
	ZM.overrides = {"sight": 0.1}
	zf.state = zf.S.CHASE
	zf.clock += 9.0
	zf._decide()
	r.check("Zombies: a glimpse starts the 10 s again", glimpse and zf.state == zf.S.CHASE, "seen %s state %d" % [glimpse, zf.state])
	zf.clock += 1.5
	zf._decide()
	r.check("Zombies: 10 s out of sight, it gives up", zf.state == zf.S.WANDER, "state %d, %.1f s unseen" % [zf.state, zf._now() - zf.last_seen])
	ZM.overrides = {}
	zf.state = zf.S.CHASE
	zf.last_seen = zf._now() - 1.0
	var space3: PhysicsDirectSpaceState3D = r.get_tree().current_scene.get_world_3d().direct_space_state
	var eye: Vector3 = gd.playerPosition + Vector3.UP * 1.2
	var dir := fwd
	for c in [fwd, -fwd, fwd.cross(Vector3.UP), -fwd.cross(Vector3.UP)]:     # a spot with a clear line to you
		var from3: Vector3 = gd.playerPosition + c * 5.0 + Vector3.UP * 1.6
		if space3.intersect_ray(PhysicsRayQueryParameters3D.create(from3, eye, zf.SIGHT_MASK)).is_empty():
			dir = c
			break
	zf.global_basis = Basis.looking_at(dir, Vector3.UP)          # its back to you, a few metres off
	zf.global_position = gd.playerPosition + dir * 5.0
	await r.get_tree().physics_frame
	r.check("Zombies: a hunter keeps you in view behind it", zf.Sees(), "aggro %s" % zf._aggro())
	# Real cover: a wall between you and it, ten seconds on, it is gone
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var wcs := CollisionShape3D.new()
	var wsh := BoxShape3D.new()
	wsh.size = Vector3(6, 6, 0.3)
	wcs.shape = wsh
	wall.add_child(wcs)
	r.get_tree().current_scene.add_child(wall)
	wall.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), gd.playerPosition + dir * 2.5 + Vector3.UP)
	await r.get_tree().physics_frame
	await r.get_tree().physics_frame
	var covered: bool = not zf.Sees()
	zf.last_seen = zf._now()
	zf.last_heard = zf._now() - 30.0
	zf.clock += 10.5
	zf._decide()
	r.check("Zombies: behind real cover, 10 s on it gives up", covered and zf.state == zf.S.WANDER, "covered %s state %d" % [covered, zf.state])
	# ...even with a shut door to break: it stops swinging
	zf.state = zf.S.DOOR
	zf.door = zf
	zf.last_seen = zf._now()
	zf.clock += 9.0
	zf._decide()
	var bashing: bool = zf.state == zf.S.DOOR
	zf.clock += 1.5
	zf._decide()
	r.check("Zombies: at a door, 10 s unseen it gives up", bashing and zf.state == zf.S.WANDER and zf.door == null, "bashing at 9 s %s, state %d" % [bashing, zf.state])
	wall.queue_free()
	zf.queue_free()

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

	# Headshots kill; the body can be searched. Top the health up first so the
	# kill comes from the decapitating blow, not attrition: a legless crawler is
	# already near death, and a headshot does three times the damage.
	z.health = 1000.0
	var hp: float = z.health
	head_hb.ApplyDamage(30.0, fwd, null)
	r.check("Zombies: headshots hit hard", hp - z.health >= 90.0, "%.0f" % (hp - z.health))
	head_hb.ApplyDamage(100.0, fwd, null)
	await _frames(r, 2)
	r.check("Zombies: dead", z.dead and not z.model.find_child("Z_Head", true, false).visible)
	var loot = z.get_node_or_null("CS_Loot")
	r.check("Zombies: the body can be searched", loot != null and loot.has_method("Interact") and loot.containerName == "Zombie")
	# searched the player's way: through the game's loot screen
	var ammo_item = null
	for it in load("res://Loot/LT_Master.tres").items:
		if it and str(it.type) == "Ammo":
			ammo_item = it
			break
	loot.CreateLoot(ammo_item)
	var ui_mgr = r.get_tree().current_scene.get_node("/root/Map/Core/UI")
	var iface = ui_mgr.get_node("Interface")
	r.check("Zombies: the body makes the game's search sound", loot.audioEvent != null)
	loot.Interact()
	await _frames(r, 30)
	r.check("Zombies: the body opens in the loot screen", iface.container == loot and iface.visible, "container %s" % str(iface.container))
	await _frames(r, 240)
	ui_mgr.Return()
	await _frames(r, 10)
	# reopened, then the body is cleared away while still open
	loot.Interact()
	await _frames(r, 20)
	z.queue_free()
	await _frames(r, 60)
	ui_mgr.Return()
	await _frames(r, 10)
	r.check("Zombies: a body cleared away while searched closes cleanly", not iface.visible)
	z = null
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
	# ...into boards of its own wood (never the hidden navigation blocker's white boxes)
	var pieces: Array = ZM.debris.filter(func(p): return is_instance_valid(p))
	var bad_src := []
	var no_mat := 0
	var biggest := 0.0
	var scaled := 0
	for p in pieces:
		var src = r.get_node_or_null(NodePath(str(p.get_meta("cs_src"))))
		if src == null or src.layers == 0 or str(src.get_path()).contains("Navblock"):
			bad_src.append(str(p.get_meta("cs_src")))
		var mi: MeshInstance3D = p.get_child(0)
		if mi.get_active_material(0) == null:
			no_mat += 1
		if absf(p.global_basis.get_scale().length() - sqrt(3.0)) > 0.01 or p.collision_mask != 25:
			scaled += 1                                  # ...and it falls like the game's ragdolls, never shoving loot
		var box: AABB = mi.get_aabb()
		biggest = maxf(biggest, maxf(box.size.x, maxf(box.size.y, box.size.z)))
	r.check("Zombies: a wooden door splits into 8-14 boards", pieces.size() >= 8 and pieces.size() <= 14, "%d pieces" % pieces.size())
	r.check("Zombies: door pieces come from the door itself", bad_src.is_empty(), str(bad_src))
	r.check("Zombies: door pieces wear the door's material", no_mat == 0, "%d without" % no_mat)
	r.check("Zombies: door pieces are board sized and unscaled", scaled == 0 and biggest < 1.3 and biggest > 0.05, "%d scaled, biggest %.2f m" % [scaled, biggest])
	var fx: Node = r.get_tree().current_scene
	r.check("Zombies: splinters and dust burst from it", fx.find_children("CS_Splinters", "GPUParticles3D", true, false).size() > 0 and fx.find_children("CS_Dust", "GPUParticles3D", true, false).size() > 0)
	var extra_doors := []
	for i in 10:
		var d2 = load("res://Assets/Shack_A/Shack_A_Door_L.tscn").instantiate()
		r.get_tree().current_scene.add_child(d2)
		d2.global_position = feet + Vector3(i * 3.0, -60, 0)
		ZM.break_door(ZM.door_of(d2.find_children("*", "CollisionShape3D", true, false)[0]), d2.global_position + Vector3(0, 1, -1))
		extra_doors.append(d2)
	await _frames(r, 2)
	r.check("Zombies: door debris is capped", ZM.debris.filter(func(p): return is_instance_valid(p) and not p.is_queued_for_deletion()).size() <= ZM.MAX_DEBRIS, "%d" % ZM.debris.size())
	for d2 in extra_doors:
		d2.queue_free()
	for p in ZM.debris:
		if is_instance_valid(p):
			p.queue_free()
	ZM.debris.clear()
	# A steel container door comes off whole, never in wooden boards
	var cd = load("res://Assets/Container_Shipping/Container_Shipping_Door_L.tscn").instantiate()
	r.get_tree().current_scene.add_child(cd)
	cd.global_position = feet + Vector3(0, -70, 0)
	var cdn = ZM.door_of(cd.find_children("*", "CollisionShape3D", true, false)[0])
	var cpanel: MeshInstance3D = null
	for m in ZM._door_meshes(cdn):
		if cpanel == null or ZM._area(m.get_aabb()) > ZM._area(cpanel.get_aabb()):
			cpanel = m
	r.check("Zombies: a container door is metal", cdn != null and ZM._surface_of(cdn, cpanel) == "Metal" and ZM._surface_of(dn, dn.find_children("*", "MeshInstance3D", true, false)[0]) == "Wood")
	cd.queue_free()

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


func _props(st: SceneState, path: String) -> Dictionary:
	for i in st.get_node_count():
		if str(st.get_node_path(i)) == "./" + path:
			var out := {}
			for p in st.get_node_property_count(i):
				out[str(st.get_node_property_name(i, p))] = st.get_node_property_value(i, p)
			return out
	return {}


# On a real map: a zombie follows you from outside, in through the door and up
# the stairs to an upper floor, the way the game's enemies get there.
func run_last(r) -> void:
	Loader.LoadScene("Village")
	var ok: bool = await r.wait_for_map("Village", 120.0)
	r.check("Zombies: Village loads for the chase", ok)
	if ok:
		await _chase_indoors(r)
	r.check("Zombies: back to Tutorial", await r.reload_tutorial())


func _chase_indoors(r) -> void:
	var gd = load("res://Resources/GameData.tres")
	var keep_health: float = gd.health
	for sp in ZM.spawners:
		if is_instance_valid(sp):
			sp.active = false
	for other in ZM.living.duplicate():
		if is_instance_valid(other) and other.active:
			other.Deactivate()
	var player = r.get_node("/root/Map/Core/Controller")
	var map: RID = player.get_world_3d().get_navigation_map()
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	await _frames(r, 10)
	# An upper floor indoors (another level of the navigation mesh right under
	# it, a roof over it), and a way up to it from outside.
	var region: NavigationRegion3D = r.get_tree().current_scene.find_children("*", "NavigationRegion3D", true, false)[0]
	var verts: PackedVector3Array = region.navigation_mesh.get_vertices()
	var home: Vector3 = player.global_position
	var near := []
	for i in range(0, verts.size(), 5):
		var v: Vector3 = region.global_transform * verts[i]
		if v.distance_to(home) < 250.0:
			near.append(v)
	near.sort_custom(func(a, b): return a.distance_to(home) < b.distance_to(home))
	var from := Vector3.INF
	var to := Vector3.INF
	var route := 0.0
	for v in near.slice(0, 4000):
		var low := NavigationServer3D.map_get_closest_point(map, v - Vector3(0, 2.6, 0))
		if v.y - low.y < 2.2 or ((low - v) * Vector3(1, 0, 1)).length() > 1.0:
			continue
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(v + Vector3.UP * 0.5, v + Vector3.UP * 6.0, 49)).is_empty():
			continue
		for k in 8:
			var s := NavigationServer3D.map_get_closest_point(map, Vector3(v.x + cos(k * TAU / 8) * 15.0, low.y, v.z + sin(k * TAU / 8) * 15.0))
			if absf(s.y - low.y) > 1.0 or not space.intersect_ray(PhysicsRayQueryParameters3D.create(s + Vector3.UP * 0.5, s + Vector3.UP * 10.0, 49)).is_empty():
				continue
			var q := NavigationPathQueryParameters3D.new()
			q.map = map
			q.start_position = s
			q.target_position = v
			var res := NavigationPathQueryResult3D.new()
			NavigationServer3D.query_path(q, res)
			var path := res.get_path()
			var length := 0.0
			for j in range(1, path.size()):
				length += path[j].distance_to(path[j - 1])
			if path.size() > 2 and path[-1].distance_to(v) < 0.5 and length < 70.0:
				from = s
				to = v
				route = length
				break
		if from != Vector3.INF:
			break
	r.check("Zombies: an upper floor indoors on the Village map", from != Vector3.INF)
	if from == Vector3.INF:
		return
	player.global_position = to + Vector3.UP * 0.15
	player.velocity = Vector3.ZERO
	await _frames(r, 20)
	ZM.overrides = {"aggro_seconds": 600.0}         # the way up, not losing you: it stays on your trail
	var z := _zombie(r, from - Vector3.UP * 0.2)
	await _frames(r, 2)
	z.last_seen = z._now()
	z.target = gd.playerPosition
	z._set_state(z.S.CHASE)
	var worst_off := 0.0          # furthest from the walkable mesh (into a wall)
	var worst_gap := 0.0          # feet off the floor under it
	var floating := 0
	var top := -1000.0
	var moved := 0.0
	var run_time := 0.0
	var last: Vector3 = z.global_position
	var frames := 0
	while frames < 9000 and z.state != z.S.ATTACK and z.global_position.distance_to(gd.playerPosition) > 2.0:
		await _frames(r, 6)
		frames += 6
		gd.health = 100.0
		var at: Vector3 = z.global_position + Vector3.UP * z.HEIGHT_OFFSET
		var c := NavigationServer3D.map_get_closest_point(map, at)
		worst_off = maxf(worst_off, ((c - at) * Vector3(1, 0, 1)).length())
		var feet: Vector3 = z.model.global_position
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.6, feet + Vector3.DOWN * 0.8, z.GROUND_MASK))
		if hit.is_empty():
			floating += 1
		else:
			worst_gap = maxf(worst_gap, absf(feet.y - hit.position.y))
		top = maxf(top, z.global_position.y)
		var step: float = z.global_position.distance_to(last)
		if z.state == z.S.CHASE and step > 0.01 and not z._busy():
			moved += step
			run_time += 6.0 / Engine.physics_ticks_per_second
		last = z.global_position
	var reached: bool = z.state == z.S.ATTACK or z.global_position.distance_to(gd.playerPosition) <= 2.0
	r.check("Zombies: follows you indoors and up to the next floor", reached and top > from.y + 1.8, "%s after %.0f s, %.1f m up (route %.0f m, %.1f m up), %.1f m left" % [reached, frames / float(Engine.physics_ticks_per_second), top - from.y, route, to.y - from.y, z.global_position.distance_to(gd.playerPosition)])
	r.check("Zombies: never inside a wall", worst_off < 0.35, "%.2f m off the walkable mesh" % worst_off)
	r.check("Zombies: feet on the floor all the way", floating == 0 and worst_gap < 0.3, "%d samples floating, worst gap %.2f m" % [floating, worst_gap])
	r.check("Zombies: hunts at a real pace", run_time > 0.0 and moved / run_time > 1.1, "%.2f m/s" % (moved / maxf(run_time, 0.001)))
	# A one-shot (a stagger) plays where it stands, then it gets going again
	z.global_position = from - Vector3.UP * 0.2
	z.last_seen = z._now()
	z._set_state(z.S.CHASE)
	await _frames(r, 90)
	var played: bool = z._play("hit", 0.0, true, 1.3)
	var p0: Vector3 = z.global_position
	await _frames(r, 40)
	r.check("Zombies: no sliding while a one-shot plays", played and z.global_position.distance_to(p0) < 0.01, "%.2f m" % z.global_position.distance_to(p0))
	var w := 0
	while z._busy() and w < 1200:
		await _frames(r, 1)
		w += 1
	z.last_seen = z._now()
	await _frames(r, 30)
	var clip: Animation = z.anim.get_animation(z.current_anim)
	r.check("Zombies: no frozen pose after a one-shot", z.anim.is_playing() and clip.loop_mode != Animation.LOOP_NONE and z.global_position.distance_to(p0) > 0.05, "%s playing %s" % [z.current_anim, z.anim.is_playing()])
	ZM.overrides = {}
	gd.health = keep_health
	z.queue_free()
	await _frames(r, 2)
