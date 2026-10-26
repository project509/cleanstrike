# CleanStrike Zombies: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_zombies"
const VERSION := "0.1.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"health": 1.0,            # zombie health (x); 250 at 1
	"damage": 60.0,           # a blow takes 15-30 health before armour
	"runners": 0.15,          # share of zombies that run
	"horde": 2.0,             # how many more than the game's enemies
	"hearing": 1.0,           # gunshots carry 140 m at 1
	"sight": 35.0,
	"forget_seconds": 180.0,  # unseen this long, they lose interest
	"alert_radius": 35.0,     # a zombie that hears or sees you calls those this close
	"door_hits": 10,
	"loot_chance": 0.25,
}

const MODEL := "res://CSZombies/Model/Zombie.scn"
const ZOMBIE := preload("res://CSZombies/Zombie.gd")
const ZHITBOX := preload("res://CSZombies/ZHitbox.gd")

# Natural speed of each moving clip (m/s), to match feet to ground.
const CLIP_SPEED := {"walk": 1.0, "walk_2": 1.1, "walk_3": 1.0, "stumble": 0.8, "run": 3.0, "run_2": 3.0, "crawl": 0.4, "crawl_run": 1.0}

# part: [bone, to bone, radius, meshes it carries, parts that go with it, health]
const PARTS := {
	"head": ["Head", "", 0.13, ["Z_Head"], [], 120.0],
	"torso": ["Chest", "", 0.2, [], [], 0.0],
	"arm_l_upper": ["LeftUpperArm", "LeftLowerArm", 0.07, ["Z_L_Upperarm", "Z_L_Forearm", "Z_L_ArmPalm"], ["arm_l_lower"], 90.0],
	"arm_l_lower": ["LeftLowerArm", "LeftHand", 0.06, ["Z_L_Forearm", "Z_L_ArmPalm"], [], 60.0],
	"arm_r_upper": ["RightUpperArm", "RightLowerArm", 0.07, ["Z_R_Upperarm", "Z_R_Forearm", "Z_R_ArmPalm"], ["arm_r_lower"], 90.0],
	"arm_r_lower": ["RightLowerArm", "RightHand", 0.06, ["Z_R_Forearm", "Z_R_ArmPalm"], [], 60.0],
	"leg_l_upper": ["LeftUpperLeg", "LeftLowerLeg", 0.1, ["Z_L_LegThigh", "Z_L_LegCalf"], ["leg_l_lower"], 110.0],
	"leg_l_lower": ["LeftLowerLeg", "LeftFoot", 0.08, ["Z_L_LegCalf"], [], 80.0],
	"leg_r_upper": ["RightUpperLeg", "RightLowerLeg", 0.1, ["Z_R_LegThigh", "Z_R_LegCalf"], ["leg_r_lower"], 110.0],
	"leg_r_lower": ["RightLowerLeg", "RightFoot", 0.08, ["Z_R_LegCalf"], [], 80.0],
}

static var _scene: PackedScene
static var living: Array = []
static var corpses: Array = []
static var _blood_mat: StandardMaterial3D
static var last_shot := -1000.0          # when and where you last fired
static var last_shot_at := Vector3.ZERO

# Self-test hook: values here win over the player's settings.
static var overrides := {}


static func cs() -> Object:
	return Engine.get_meta("Cleanstrike") if Engine.has_meta("Cleanstrike") else null


# False when Cleanstrike rolled this mod back: stay vanilla.
static func active() -> bool:
	var c := cs()
	return c == null or c.is_loaded(MOD_ID)


static func setting(key: String):
	if overrides.has(key):
		return overrides[key]
	var fallback = DEFAULTS.get(key)
	var c := cs()
	if c == null:
		return fallback
	var v = c.get_setting(MOD_ID, key, fallback)
	# Settings files store every number as a float: convert to the default's type.
	if typeof(fallback) == TYPE_INT and typeof(v) == TYPE_FLOAT:
		return int(round(v))
	if typeof(fallback) == TYPE_FLOAT and typeof(v) == TYPE_INT:
		return float(v)
	return v if typeof(v) == typeof(fallback) else fallback


static func say(text: String) -> void:
	var c := cs()
	if c:
		c.log_message(MOD_ID, text)
	else:
		print("[%s] %s" % [MOD_ID, text])


static func note_shot(at: Vector3) -> void:
	last_shot = Time.get_ticks_msec() / 1000.0
	last_shot_at = at


static func limb_health(part: String) -> float:
	return float(PARTS[part][5]) * float(setting("health"))


# ---------------------------------------------------------------- the zombie

# One packed zombie: model, navigation, a hitbox per body part.
static func scene() -> PackedScene:
	if _scene:
		return _scene
	var root := Node3D.new()
	root.name = "Zombie"
	root.set_script(ZOMBIE)
	var model: Node3D = load(MODEL).instantiate()
	model.name = "Model"
	model.rotation.y = PI          # the model faces +z; the zombie faces -z like everything else
	root.add_child(model)
	# Local, so the hitboxes added inside it are kept when packed
	model.scene_file_path = ""
	model.owner = root
	for n in model.find_children("*", "", true, false):
		n.owner = root
	var agent := NavigationAgent3D.new()
	agent.name = "Agent"
	agent.path_desired_distance = 0.5
	agent.target_desired_distance = 1.0
	root.add_child(agent)
	agent.owner = root
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var to_model := _rel(sk, model)
	for part in PARTS:
		var p: Array = PARTS[part]
		var bone := sk.find_bone(p[0])
		if bone < 0:
			continue
		var bone_m: Transform3D = to_model * sk.get_bone_global_rest(bone)
		var att := BoneAttachment3D.new()
		att.name = "HB_" + part
		att.bone_name = p[0]
		sk.add_child(att)
		att.owner = root
		var body := StaticBody3D.new()
		body.name = "Hitbox"
		body.collision_layer = 64
		body.collision_mask = 0
		body.set_script(ZHITBOX)
		body.set("part", part)
		body.set("type", "Head" if part == "head" else "Torso")
		att.add_child(body)
		body.owner = root
		var col := CollisionShape3D.new()
		var a: Vector3 = bone_m.origin
		var b: Vector3
		if part == "head":
			b = a + Vector3(0, 0.16, 0)
		elif part == "torso":
			a = (to_model * sk.get_bone_global_rest(sk.find_bone("Hips"))).origin
			b = (to_model * sk.get_bone_global_rest(sk.find_bone("Neck"))).origin
		else:
			b = (to_model * sk.get_bone_global_rest(sk.find_bone(p[1]))).origin
			if p[1].ends_with("Hand") or p[1].ends_with("Foot"):
				b += (b - a).normalized() * 0.12                 # the hand or foot too
		var cap := CapsuleShape3D.new()
		cap.radius = p[2]
		cap.height = maxf(a.distance_to(b) + p[2] * 2.0, p[2] * 2.0 + 0.01)
		col.shape = cap
		var mid_m := Transform3D(_basis_y(b - a), (a + b) / 2.0)
		col.transform = bone_m.affine_inverse() * mid_m        # in the bone space at rest
		body.add_child(col)
		col.owner = root
	_scene = PackedScene.new()
	_scene.pack(root)
	root.free()
	return _scene


static func _basis_y(dir: Vector3) -> Basis:
	if dir.length() < 0.001:
		return Basis()
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y)).orthonormalized()


static func _rel(node: Node, top: Node) -> Transform3D:
	var t := Transform3D()
	var x: Node = node
	while x and x != top:
		if x is Node3D:
			t = x.transform * t
		x = x.get_parent()
	return t


static func register(z) -> void:
	living.append(z)


static func release() -> void:
	_scene = null
	living.clear()
	corpses.clear()
	_blood_mat = null


# ---------------------------------------------------------------- the pack

# Every zombie within the alert radius comes to look, after a moment.
static func alert_near(from, at: Vector3) -> int:
	living = living.filter(func(z): return is_instance_valid(z) and not z.dead)
	var n := 0
	var r := float(setting("alert_radius"))
	for z in living:
		if z == from or not z.active or z.global_position.distance_to(from.global_position) > r:
			continue
		n += 1
		var t: SceneTreeTimer = from.get_tree().create_timer(randf_range(0.3, 1.8), false)
		t.timeout.connect(func():
			if is_instance_valid(z) and not z.dead:
				z.Hear(at, true))
	return n


static func hurt_player(tree: SceneTree, damage: float) -> void:
	var ch = tree.root.get_node_or_null("Map/Core/Controller/Character")
	if ch and ch.has_method("WeaponDamage"):
		ch.WeaponDamage(int(damage), 0)


# ---------------------------------------------------------------- doors

static func door_of(n: Node) -> Node:
	while n:
		if n is Door:
			return n
		n = n.get_parent()
	return null


# One blow. True when the door gives way.
static func hit_door(d: Node) -> bool:
	var hits := (int(d.get_meta("cs_hits")) if d.has_meta("cs_hits") else 0) + 1
	d.set_meta("cs_hits", hits)
	if hits < int(setting("door_hits")):
		return false
	break_door(d)
	return true


# The door bursts into planks and the doorway is clear.
static func break_door(d: Node3D) -> void:
	for m in d.find_children("*", "MeshInstance3D", true, false):
		if not m.visible or m.mesh == null:
			continue
		var box: AABB = m.get_aabb()
		var mat: Material = m.get_active_material(0)
		for i in 6:
			var piece := RigidBody3D.new()
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(box.size.x * randf_range(0.25, 0.5), box.size.y * randf_range(0.15, 0.3), maxf(minf(box.size.z, box.size.x), 0.04))
			bm.material = mat
			mi.mesh = bm
			piece.add_child(mi)
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = bm.size
			cs.shape = sh
			piece.add_child(cs)
			piece.collision_layer = 1
			piece.collision_mask = 1
			d.get_tree().current_scene.add_child(piece)
			piece.global_transform = m.global_transform * Transform3D(Basis(), box.position + box.size * Vector3(randf(), randf(), 0.5))
			piece.apply_central_impulse(Vector3(randf_range(-2, 2), randf_range(0.5, 2.5), randf_range(-2, 2)))
			piece.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
			_expire(piece, 120.0)
	d.isOpen = true
	d.hide()
	for c in d.find_children("*", "CollisionShape3D", true, false):
		c.set_deferred("disabled", true)
	d.set_meta("cs_broken", true)


static func _expire(n: Node, seconds: float) -> void:
	n.get_tree().create_timer(seconds, false).timeout.connect(func():
		if is_instance_valid(n):
			n.queue_free())


# ---------------------------------------------------------------- gore

static func blood_material() -> StandardMaterial3D:
	if _blood_mat == null:
		_blood_mat = StandardMaterial3D.new()
		_blood_mat.albedo_color = Color(1, 1, 1)
		_blood_mat.roughness = 0.3
		_blood_mat.vertex_color_use_as_albedo = true
	return _blood_mat


# A burst of blood droplets.
static func burst(parent: Node, at: Vector3, dir: Vector3, amount: int, life := 0.8) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = life
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.color = Color(0.75, 0.04, 0.03)
	p.process_material = pm
	var sm := SphereMesh.new()
	sm.radius = 0.009
	sm.height = 0.018
	sm.material = blood_material()
	p.draw_pass_1 = sm
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	_expire(p, life + 0.5)
	return p


static func _dhe():
	if ResourceLoader.exists("res://CSDeathHitEffects/Mod.gd"):
		var d = load("res://CSDeathHitEffects/Mod.gd")
		return d if d.active() else null
	return null


static func gore_hit(z: Node3D, at: Vector3, vector: Vector3) -> void:
	burst(z.get_tree().current_scene, at, -vector + Vector3.UP * 0.3, 14)
	var d = _dhe()
	if d:
		d.splatter(z, at, vector, z.hitboxes.map(func(h): return h.get_rid()))


# Off it comes: the limb, posed as it is right now, flies; the stump bleeds.
static func sever(z, part: String, vector: Vector3) -> void:
	var p: Array = PARTS[part]
	for name in p[3]:
		var mi: MeshInstance3D = z.model.find_child(name, true, false)
		if mi == null or not mi.visible:
			continue
		var baked: Mesh = mi.bake_mesh_from_current_skeleton_pose()
		if baked == null:                           # no mesh data (headless): a stand-in
			var cap := CapsuleMesh.new()
			cap.radius = 0.06
			cap.height = 0.4
			baked = cap
		mi.visible = false
		var piece := RigidBody3D.new()
		var m := MeshInstance3D.new()
		m.mesh = baked
		m.material_override = mi.material_override
		piece.add_child(m)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		var box := baked.get_aabb()
		sh.size = box.size.max(Vector3(0.05, 0.05, 0.05))
		cs.shape = sh
		cs.position = box.get_center()
		piece.add_child(cs)
		piece.collision_layer = 1
		piece.collision_mask = 1
		piece.mass = 4.0
		piece.name = "CS_Limb"
		z.get_tree().current_scene.add_child(piece)
		piece.global_transform = mi.global_transform if not (baked is CapsuleMesh) else Transform3D(Basis(), z.global_position + Vector3.UP * 0.5)
		piece.apply_central_impulse(vector.normalized() * 3.0 + Vector3.UP * 2.0)
		piece.angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
		_expire(piece, 180.0)
	for other in [part] + p[4]:
		z.lost[other] = true
		var a = z.skeleton.get_node_or_null("HB_" + other)
		if a:
			a.get_node("Hitbox").collision_layer = 0
	var att = z.skeleton.get_node_or_null("HB_" + part)
	var at: Vector3 = att.global_position if att else z.global_position + Vector3.UP
	burst(z.get_tree().current_scene, at, vector + Vector3.UP, 40, 1.2)
	var d = _dhe()
	if d:
		d.splatter(z, at, Vector3.DOWN, [])


# ---------------------------------------------------------------- death

static func died(z, _vector: Vector3) -> void:
	living.erase(z)
	corpses.append(z)
	corpses = corpses.filter(func(c): return is_instance_valid(c))
	while corpses.size() > 24:
		corpses.pop_front().queue_free()
	var d = _dhe()
	if d:
		z.get_tree().create_timer(2.0, false).timeout.connect(func():
			if is_instance_valid(z):
				d.pool(z))
	_corpse_loot(z)
	if ResourceLoader.exists("res://CSKillCounter/Mod.gd") and load("res://CSKillCounter/Mod.gd").active():
		load("res://CSKillCounter/Mod.gd").add("Zombie")
	if ResourceLoader.exists("res://CSProgression/Mod.gd") and load("res://CSProgression/Mod.gd").active():
		load("res://CSProgression/Mod.gd").add_xp(15.0, "zombie")


# A body you can search: a small chance of a few rounds or something to eat.
static func _corpse_loot(z: Node3D) -> Node:
	var c := Node3D.new()
	c.name = "CS_Loot"
	c.set_script(load("res://Scripts/LootContainer.gd"))
	c.set("containerName", "Zombie")
	c.set("limit", "CS_Nothing")
	var body := StaticBody3D.new()
	body.collision_layer = 16
	body.collision_mask = 0
	body.add_to_group("Interactable", true)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.6, 0.6, 1.6)
	cs.shape = sh
	cs.position = Vector3(0, 0.3, 0)
	body.add_child(cs)
	c.add_child(body)
	z.add_child(c)
	body.owner = c
	if randf() < float(setting("loot_chance")):
		var pool := []
		for it in load("res://Loot/LT_Master.tres").items:
			if it and (str(it.type) == "Ammo" or (str(it.type) in ["Consumables", "Consumable"] and it.energy > 0.0)):
				pool.append(it)
		if not pool.is_empty():
			c.CreateLoot(pool.pick_random())
	return c
