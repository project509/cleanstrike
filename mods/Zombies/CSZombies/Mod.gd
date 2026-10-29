# Road to Hell (CleanStrike Zombies): shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_zombies"
const VERSION := "1.1.4"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"health": 1.0,            # zombie health (x); 125 at 1
	"damage": 60.0,           # a blow takes 15-30 health before armour
	"speed": 1.0,             # how fast they move (and animate) (x)
	"chase_speed": 1.5,       # m/s once they are after you (you walk 2.5, sprint 5)
	"rage_chance": 0.12,      # shot at, a zombie may charge you for a few seconds
	"horde": 4.0,             # how many more than the game's enemies
	"respawn": true,          # the dead are replaced, 30-90 s later
	"escalation": 1.0,        # how hard the pressure builds while you are noticed
	"start_share": 0.5,       # share of the alive cap already out when you arrive
	"hearing": 1.0,           # gunshots carry 140 m at 1
	"sight": 15.0,
	"aggro_seconds": 10.0,    # line of sight broken this long, they lose you
	"alert_radius": 10.0,     # a zombie that hears or sees you calls those this close
	"door_hits": 10,
	"loot_chance": 0.25,
}

const MODEL := "res://CSZombies/Model/Zombie.scn"
const ZOMBIE := preload("res://CSZombies/Zombie.gd")
const ZHITBOX := preload("res://CSZombies/ZHitbox.gd")

# Natural speed of each moving clip (m/s): how fast the planted foot sweeps back
# (measured from the clips). Zombies move at exactly this times the clip rate,
# so feet never skate.
const CLIP_SPEED := {"walk": 0.45, "walk_2": 0.59, "walk_3": 0.46, "stumble": 0.32, "run": 2.13, "run_2": 2.17, "crawl": 0.43, "crawl_run": 2.15}

# part: [bone, to bone, radius, meshes it carries, parts that go with it, health]
const PARTS := {
	"head": ["Head", "", 0.13, ["Z_Head"], [], 120.0],
	"torso": ["Chest", "", 0.2, [], [], 0.0],
	"arm_l_upper": ["LeftUpperArm", "LeftLowerArm", 0.07, ["Z_L_Upperarm", "Z_L_Forearm", "Z_L_ArmPalm"], ["arm_l_lower"], 40.0],
	"arm_l_lower": ["LeftLowerArm", "LeftHand", 0.06, ["Z_L_Forearm", "Z_L_ArmPalm"], [], 25.0],
	"arm_r_upper": ["RightUpperArm", "RightLowerArm", 0.07, ["Z_R_Upperarm", "Z_R_Forearm", "Z_R_ArmPalm"], ["arm_r_lower"], 40.0],
	"arm_r_lower": ["RightLowerArm", "RightHand", 0.06, ["Z_R_Forearm", "Z_R_ArmPalm"], [], 25.0],
	"leg_l_upper": ["LeftUpperLeg", "LeftLowerLeg", 0.1, ["Z_L_LegThigh", "Z_L_LegCalf"], ["leg_l_lower"], 50.0],
	"leg_l_lower": ["LeftLowerLeg", "LeftFoot", 0.08, ["Z_L_LegCalf"], [], 35.0],
	"leg_r_upper": ["RightUpperLeg", "RightLowerLeg", 0.1, ["Z_R_LegThigh", "Z_R_LegCalf"], ["leg_r_lower"], 50.0],
	"leg_r_lower": ["RightLowerLeg", "RightFoot", 0.08, ["Z_R_LegCalf"], [], 35.0],
}

static var _scene: PackedScene
static var living: Array = []
static var corpses: Array = []
static var _blood_mat: StandardMaterial3D
static var spawners: Array = []
static var heat := 0.0                    # 0 calm .. 1 swarming: builds while you are noticed
static var noticed_at := -1000.0          # last time a zombie saw or heard you
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


const VOICES := {"moan": 10, "scream": 6, "attack": 6, "hit": 3, "death": 3}
const MAX_VOICES := 6                    # a horde stays readable

static var _sounds := {}
static var speaking := 0


static func sound(kind: String) -> AudioStream:
	var key := "%s_%d" % [kind, randi_range(1, int(VOICES.get(kind, 1)))]
	if not _sounds.has(key):
		var bytes := FileAccess.get_file_as_bytes("res://CSZombies/Sounds/%s.wav" % key)
		_sounds[key] = AudioStreamWAV.load_from_buffer(bytes) if bytes.size() > 44 else null
	return _sounds[key]


# A shot: every zombie in earshot hears it, right away (nothing to miss).
static func note_shot(at: Vector3) -> int:
	notice(0.06)
	last_shot = Time.get_ticks_msec() / 1000.0
	last_shot_at = at
	var reach := 140.0 * float(setting("hearing"))
	var n := 0
	for z in living:
		if is_instance_valid(z) and z.active and not z.dead and z.global_position.distance_to(at) < reach:
			z.Hear(at, true)
			n += 1
	return n


# Pressure: every shot and every zombie on you raises it; it only cools once
# nothing has seen or heard you for 30 s.
static func notice(amount: float) -> void:
	noticed_at = Time.get_ticks_msec() / 1000.0
	heat = clampf(heat + amount * float(setting("escalation")), 0.0, 1.0)


static func cool(delta: float) -> void:
	if Time.get_ticks_msec() / 1000.0 - noticed_at > 30.0:
		heat = maxf(0.0, heat - delta / 120.0)          # about two minutes hidden to calm fully


static func limb_health(part: String) -> float:
	return float(PARTS[part][5]) * float(setting("health"))


# ---------------------------------------------------------------- the zombie

# One packed zombie: model, navigation, a hitbox per body part. Body and
# navigation agent as the game's own enemies have them (AI_Bandit.tscn), so it
# can walk wherever they walk.
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
	agent.path_desired_distance = 0.2
	agent.path_height_offset = 0.2
	agent.target_desired_distance = 1.0
	root.add_child(agent)
	agent.owner = root
	# A solid capsule on layer 2: the player bumps into it; bullets, sight and
	# the zombies' own rays pass it by (none of them look at layer 2).
	var solid := StaticBody3D.new()
	solid.name = "Collision"
	solid.collision_layer = 2
	solid.collision_mask = 2
	root.add_child(solid)
	solid.owner = root
	var solid_shape := CollisionShape3D.new()
	solid_shape.name = "Shape"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.4
	solid_shape.shape = capsule
	solid_shape.position = Vector3(0, 1.2, 0)
	solid.add_child(solid_shape)
	solid_shape.owner = root
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
	spawners.clear()
	heat = 0.0
	_sounds.clear()
	living.clear()
	corpses.clear()
	_blood_mat = null
	debris.clear()
	_dust_mat = null


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


# One blow. True when the door gives way. from: where the blow came from.
static func hit_door(d: Node, from := Vector3.INF) -> bool:
	var hits := (int(d.get_meta("cs_hits")) if d.has_meta("cs_hits") else 0) + 1
	d.set_meta("cs_hits", hits)
	if hits < int(setting("door_hits")):
		return false
	break_door(d, from)
	return true


const MAX_DEBRIS := 80          # door pieces lying about at once; the oldest go first
const WOOD_DENSITY := 550.0     # kg/m3
# Where the game's door leaves (MS_Door_*) take their texture, for when the
# mesh data can't be read: front and back face, u across, v up the leaf.
const DOOR_UV := {"front": [0.4375, 0.0625], "back": [0.875, 0.5], "v": [0.9375, 0.0625]}

static var debris: Array = []
static var _dust_mat: StandardMaterial3D


# The door bursts and the doorway is clear: a wooden leaf splits into jagged
# boards wearing its own texture, with splinters, dust and a crash; a metal
# one comes off its hinges whole.
static func break_door(d: Node3D, from := Vector3.INF) -> void:
	var meshes := _door_meshes(d)
	var panel: MeshInstance3D = null
	for m in meshes:
		if panel == null or _area(m.get_aabb()) > _area(panel.get_aabb()):
			panel = m
	var scene := d.get_tree().current_scene
	if panel:
		var metal := _surface_of(d, panel) == "Metal"
		var box := panel.get_aabb()
		var centre: Vector3 = panel.global_transform * box.get_center()
		var out := panel.global_basis.z.normalized()
		if from != Vector3.INF and out.dot(centre - from) < 0.0:
			out = -out                                   # away from whoever broke it
		elif from == Vector3.INF and randf() < 0.5:
			out = -out
		if metal:
			_whole(scene, panel, 25.0, out * 2.0)
		else:
			_splinter(scene, panel, out)
			_splinters_burst(scene, panel, centre, out)
		_dust(scene, centre, box.size.y * panel.global_basis.get_scale().y)
		_crash(scene, centre, metal)
		for m in meshes:
			if m != panel:
				_whole(scene, m, 0.5, out * randf_range(1.0, 2.0))      # the handle
	d.isOpen = true
	d.hide()
	for c in d.find_children("*", "CollisionShape3D", true, false):
		c.set_deferred("disabled", true)
	d.set_meta("cs_broken", true)


static func _area(b: AABB) -> float:
	return b.size.x * b.size.y + b.size.y * b.size.z + b.size.x * b.size.z


# A local vector from leaf coordinates: u across the leaf, v up it, w through
# its thickness, placed on whichever mesh axes those turn out to be.
static func _av(ui: int, vi: int, wi: int, u: float, v: float, w: float) -> Vector3:
	var o := Vector3.ZERO
	o[ui] = u
	o[vi] = v
	o[wi] = w
	return o


# Which local axis is which for this leaf: thickness is the thinnest, height
# the taller of the other two, width the last. [width, height, thickness].
static func _leaf_axes(box: AABB) -> Array:
	var s := box.size
	var wi := 0
	for i in 3:
		if s[i] < s[wi]:
			wi = i
	var rem := [0, 1, 2]
	rem.erase(wi)
	var vi: int = rem[0] if s[rem[0]] >= s[rem[1]] else rem[1]
	var ui: int = rem[1] if vi == rem[0] else rem[0]
	return [ui, vi, wi]


# The door's own visible parts: not the navigation blocker every door
# carries (a mesh drawn on no layer).
static func _door_meshes(d: Node) -> Array:
	var out := []
	for m in d.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null or m.layers == 0 or not m.is_visible_in_tree():
			continue
		var p: Node = m.get_parent()
		var blocker := false
		while p and p != d:
			blocker = blocker or str(p.name).begins_with("Navblock")
			p = p.get_parent()
		if not blocker and _area(m.get_aabb()) > 0.0:
			out.append(m)
	return out


# What the door is made of: the panel's own body says, else most of the
# door's bodies do (a shipping container keeps its tags on hidden colliders).
static func _surface_of(d: Node, panel: Node) -> String:
	for b in panel.find_children("*", "StaticBody3D", true, false):
		if "surface" in b:
			return str(b.surface)
	var count := {}
	for b in d.find_children("*", "StaticBody3D", true, false):
		if "surface" in b:
			count[str(b.surface)] = int(count.get(str(b.surface), 0)) + 1
	var best := "Wood"
	for k in count:
		if count[k] > int(count.get(best, 0)):
			best = k
	return best


# A rigid piece of debris; never scaled (physics bodies can't be).
static func _piece(scene: Node, at: Transform3D, src: Node, mi: MeshInstance3D, size: Vector3, offset: Vector3, mass: float) -> RigidBody3D:
	var piece := RigidBody3D.new()
	piece.name = "CS_Debris"
	piece.set_meta("cs_src", str(src.get_path()))
	piece.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size.abs().max(Vector3(0.02, 0.02, 0.02))
	cs.shape = sh
	cs.position = offset
	piece.add_child(cs)
	piece.collision_layer = 256     # like the game's ragdolls: lands on every floor, walked through
	piece.collision_mask = 25
	piece.mass = maxf(mass, 0.2)
	piece.linear_damp = 0.1
	piece.angular_damp = 0.6
	piece.can_sleep = true
	piece.continuous_cd = true      # thin and fast: never through the floor
	scene.add_child(piece)
	piece.global_transform = at
	_keep(piece)
	return piece


# Debris stays a while, settles (out of the physics step once asleep), then
# shrinks away; never more than MAX_DEBRIS at once.
static func _keep(piece: RigidBody3D) -> void:
	debris = debris.filter(func(p): return is_instance_valid(p))
	debris.append(piece)
	while debris.size() > MAX_DEBRIS:
		var old = debris.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	piece.get_tree().create_timer(8.0, false).timeout.connect(func():
		if is_instance_valid(piece) and piece.sleeping:
			piece.freeze = true)
	piece.get_tree().create_timer(randf_range(40.0, 60.0), false).timeout.connect(func():
		if not is_instance_valid(piece):
			return
		var tw := piece.create_tween()
		tw.tween_property(piece.get_child(0), "scale", Vector3(0.01, 0.01, 0.01), 1.5)
		tw.tween_callback(piece.queue_free))


# A part that comes off in one piece (a metal leaf, a handle).
static func _whole(scene: Node, m: MeshInstance3D, mass: float, push: Vector3) -> RigidBody3D:
	var box := m.get_aabb()
	var sc := m.global_basis.get_scale()
	var at := _unscaled(m.global_transform)
	if at.basis.determinant() < 0.0:
		sc.x = -sc.x
		at.basis.x = -at.basis.x
	var mi := MeshInstance3D.new()
	mi.mesh = m.mesh
	mi.material_override = m.material_override
	for s in m.mesh.get_surface_count():
		mi.set_surface_override_material(s, m.get_active_material(s))
	mi.scale = sc
	var piece := _piece(scene, at, m, mi, box.size * sc, box.get_center() * sc, mass)
	piece.apply_central_impulse(push * piece.mass + Vector3.UP * piece.mass * 0.5)
	piece.angular_velocity = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
	return piece


static func _unscaled(t: Transform3D) -> Transform3D:
	return Transform3D(t.basis.orthonormalized(), t.origin)


# A wooden leaf: four or five boards across, each broken once or twice along
# its length, ragged where it broke, straight at the hinge, lock and ends.
static func _splinter(scene: Node, m: MeshInstance3D, out: Vector3) -> void:
	var box := m.get_aabb()
	var sc := m.global_basis.get_scale()
	var rot := m.global_basis.orthonormalized()
	if rot.determinant() < 0.0:
		sc.x = -sc.x
		rot.x = -rot.x
	var axes := _leaf_axes(box)
	var ui: int = axes[0]
	var vi: int = axes[1]
	var wi: int = axes[2]
	var wide: Vector3 = [rot.x, rot.y, rot.z][ui]       # the leaf's width, in the world
	var uv := _uv_maps(m, box, ui, vi, wi)
	var mat: Material = m.get_active_material(0)
	var x0: float = box.position[ui]
	var x1: float = box.end[ui]
	var y0: float = box.position[vi]
	var y1: float = box.end[vi]
	var z0: float = box.position[wi]
	var z1: float = box.end[wi]
	# boards about a metre long at most: two or three to a column, 12 or fewer in all
	var n := maxi(2, ceili((y1 - y0) * absf(sc[vi]) / 1.0))
	var cols := clampi(int(12.0 / n), 4, 5)
	var w := (x1 - x0) / cols
	var twice := range(cols)                 # columns broken once more
	twice.shuffle()
	twice = twice.slice(0, randi_range(0, maxi(0, 12 - cols * n)))
	var xs := [x0]
	for i in range(1, cols):
		xs.append(x0 + w * (i + randf_range(-0.2, 0.2)))
	xs.append(x1)
	for c in cols:
		var segs := n + (1 if c in twice else 0)
		var ys := [y0]
		for b in range(1, segs):
			ys.append(lerpf(y0, y1, (b + randf_range(-0.15, 0.15)) / segs))
		ys.append(y1)
		for k in ys.size() - 1:
			var loss: float = (xs[c + 1] - xs[c]) * randf_range(0.1, 0.3)
			var side := randf()
			var xa: float = xs[c] + loss * side
			var xb: float = xs[c + 1] - loss * (1.0 - side)
			var ya: float = ys[k]
			var yb: float = ys[k + 1]
			# the outline, round the board; spikes where it broke
			var pts := [Vector2(xa, ya)]
			if k > 0:
				pts.append(Vector2(lerpf(xa, xb, randf_range(0.3, 0.7)), ya - randf_range(0.03, 0.1)))
			pts.append(Vector2(xb, ya + (randf_range(-0.03, 0.03) if k > 0 else 0.0)))
			pts.append(Vector2(xb, yb + (randf_range(-0.03, 0.03) if k < ys.size() - 2 else 0.0)))
			if k < ys.size() - 2:
				pts.append(Vector2(lerpf(xa, xb, randf_range(0.3, 0.7)), yb + randf_range(0.03, 0.1)))
			pts.append(Vector2(xa, yb))
			var mid := _av(ui, vi, wi, (xa + xb) / 2.0, (ya + yb) / 2.0, (z0 + z1) / 2.0)
			var mi := MeshInstance3D.new()
			mi.mesh = _board(pts, z0, z1, mid, sc, uv, mat, ui, vi, wi)
			var size := _av(ui, vi, wi, xb - xa, yb - ya, z1 - z0) * sc
			var at := Transform3D(rot, m.global_transform * mid)
			var piece := _piece(scene, at, m, mi, size, Vector3.ZERO, absf(size.x * size.y * size.z) * WOOD_DENSITY)
			var lock := clampf(((xa + xb) / 2.0 - x0) / maxf(x1 - x0, 0.01), 0.0, 1.0)     # hardest by the lock
			var v := out * randf_range(1.5, 3.5) * lerpf(0.8, 1.3, lock) + wide * randf_range(-1, 1) + Vector3.UP * randf_range(0.3, 1.5)
			piece.apply_central_impulse(v * piece.mass)
			piece.angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))


# A board: its outline pushed through the leaf's thickness, both faces
# textured where they sat on the door, the edges with the grain beside them.
static func _board(pts: Array, z0: float, z1: float, mid: Vector3, sc: Vector3, uv: Dictionary, mat: Material, ui: int, vi: int, wi: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c2 := Vector2.ZERO
	for p in pts:
		c2 += p
	c2 /= pts.size()
	var centre := Vector3.ZERO
	var n := pts.size()
	for i in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		for face in [[z0, "front"], [z1, "back"]]:
			var z: float = face[0]
			_tri(st, centre, [_av(ui, vi, wi, c2.x, c2.y, z), _av(ui, vi, wi, a.x, a.y, z), _av(ui, vi, wi, b.x, b.y, z)],
				[_uv(uv[face[1]], c2), _uv(uv[face[1]], a), _uv(uv[face[1]], b)], mid, sc)
		var inward := (c2 - (a + b) / 2.0).normalized() * (z1 - z0)
		var ua := _uv(uv.front, a)
		var ub := _uv(uv.front, b)
		var ua2 := _uv(uv.front, a + inward)
		var ub2 := _uv(uv.front, b + inward)
		_tri(st, centre, [_av(ui, vi, wi, a.x, a.y, z0), _av(ui, vi, wi, b.x, b.y, z0), _av(ui, vi, wi, b.x, b.y, z1)], [ua, ub, ub2], mid, sc)
		_tri(st, centre, [_av(ui, vi, wi, a.x, a.y, z0), _av(ui, vi, wi, b.x, b.y, z1), _av(ui, vi, wi, a.x, a.y, z1)], [ua, ub2, ua2], mid, sc)
	st.set_material(mat)
	return st.commit()


# One triangle, wound and lit to face away from the board's middle.
static func _tri(st: SurfaceTool, centre: Vector3, p: Array, u: Array, mid: Vector3, sc: Vector3) -> void:
	var v := [(p[0] - mid) * sc, (p[1] - mid) * sc, (p[2] - mid) * sc]
	var nrm: Vector3 = (v[1] - v[0]).cross(v[2] - v[0])
	if nrm.length() < 1e-9:
		return
	nrm = nrm.normalized()
	if nrm.dot((v[0] + v[1] + v[2]) / 3.0 - centre) < 0.0:
		nrm = -nrm
	var order := [0, 1, 2]
	if (v[1] - v[0]).cross(v[2] - v[0]).dot(nrm) > 0.0:
		order = [0, 2, 1]                 # the game draws clockwise faces
	for i in order:
		st.set_normal(nrm)
		st.set_uv(u[i])
		st.add_vertex(v[i])


static func _uv(f: Array, p: Vector2) -> Vector2:
	return Vector2(f[0] * p.x + f[1] * p.y + f[2], f[3] * p.x + f[4] * p.y + f[5])


# How the leaf's faces map onto its texture (x, y -> u, v), fitted to its
# mesh; the game's door layout when the mesh data can't be read.
static func _uv_maps(m: MeshInstance3D, box: AABB, ui: int, vi: int, wi: int) -> Dictionary:
	var maps := {}
	var arrays: Array = m.mesh.surface_get_arrays(0) if m.mesh.get_surface_count() > 0 else []
	if arrays.size() > Mesh.ARRAY_TEX_UV and arrays[Mesh.ARRAY_VERTEX] != null and arrays[Mesh.ARRAY_TEX_UV] != null:
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var us: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var idx = arrays[Mesh.ARRAY_INDEX]
		var tris: PackedInt32Array = idx if idx != null and idx.size() > 0 else PackedInt32Array(range(vs.size()))
		var centre := box.get_center()
		var pick := {"front": [], "back": []}
		for t in range(0, tris.size() - 2, 3):
			var a := vs[tris[t]]
			var nrm := (vs[tris[t + 1]] - a).cross(vs[tris[t + 2]] - a).normalized()
			var key := "front" if (a[wi] - centre[wi]) < 0.0 else "back"
			if absf(nrm[wi]) > 0.9:
				for j in 3:
					var vert: Vector3 = vs[tris[t + j]]
					pick[key].append([Vector2(vert[ui], vert[vi]), us[tris[t + j]]])
		for key in pick:
			var f := _fit(pick[key])
			if not f.is_empty():
				maps[key] = f
	if maps.size() == 2:
		return maps
	# u across, v up the leaf, as the game's own door leaves are laid out
	var w := maxf(box.size[ui], 0.01)
	var h := maxf(box.size[vi], 0.01)
	for key in ["front", "back"]:
		var uu: Array = DOOR_UV[key]
		var vv: Array = DOOR_UV.v
		var du: float = (uu[1] - uu[0]) / w
		var dv: float = (vv[1] - vv[0]) / h
		maps[key] = [du, 0.0, uu[0] - du * box.position[ui], 0.0, dv, vv[0] - dv * box.position[vi]]
	return maps


# Least squares: u = a x + b y + c, v = d x + e y + f.
static func _fit(pairs: Array) -> Array:
	if pairs.size() < 3:
		return []
	var cx := Vector3.ZERO
	var cy := Vector3.ZERO
	var cz := Vector3.ZERO
	var ru := Vector3.ZERO
	var rv := Vector3.ZERO
	for pr in pairs:
		var r := Vector3(pr[0].x, pr[0].y, 1.0)
		cx += r * r.x
		cy += r * r.y
		cz += r * r.z
		ru += r * pr[1].x
		rv += r * pr[1].y
	var mtx := Basis(cx, cy, cz)
	if absf(mtx.determinant()) < 1e-9:
		return []
	var inv := mtx.inverse()
	var a := inv * ru
	var b := inv * rv
	return [a.x, a.y, a.z, b.x, b.y, b.z]


# Splinters off the break, the door's own wood, bouncing on the floor.
static func _splinters_burst(scene: Node, m: MeshInstance3D, at: Vector3, out: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.name = "CS_Splinters"
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 24
	p.lifetime = 1.6
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.4, 0.9, 0.05)
	pm.direction = out
	pm.spread = 60.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -360.0
	pm.angular_velocity_max = 360.0
	pm.particle_flag_rotate_y = true
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	pm.collision_bounce = 0.2
	pm.collision_friction = 0.6
	p.process_material = pm
	p.collision_base_size = 0.02
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.12, 0.008)
	bm.material = m.get_active_material(0)
	p.draw_pass_1 = bm
	scene.add_child(p)
	p.global_position = at
	p.emitting = true
	var ground := GPUParticlesCollisionBox3D.new()
	ground.size = Vector3(3, 0.1, 3)
	scene.add_child(ground)
	ground.global_position = m.global_transform * Vector3(m.get_aabb().get_center().x, m.get_aabb().position.y, 0) - Vector3(0, 0.05, 0)
	_expire(p, 3.0)
	_expire(ground, 3.0)


# A puff of dust where the door stood.
static func _dust(scene: Node, at: Vector3, height: float) -> void:
	var p := GPUParticles3D.new()
	p.name = "CS_Dust"
	p.one_shot = true
	p.explosiveness = 0.8
	p.amount = 10
	p.lifetime = 2.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.5, maxf(height, 0.5) * 0.4, 0.2)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0, 0.2, 0)
	pm.damping_min = 0.5
	pm.damping_max = 1.0
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.scale_min = 0.7
	pm.scale_max = 1.5
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(1, 1.4))
	var ct := CurveTexture.new()
	ct.curve = grow
	pm.scale_curve = ct
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = fade
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.6, 0.6)
	q.material = dust_material()
	p.draw_pass_1 = q
	scene.add_child(p)
	p.global_position = at
	p.emitting = true
	_expire(p, 3.0)


static func dust_material() -> StandardMaterial3D:
	if _dust_mat == null:
		_dust_mat = StandardMaterial3D.new()
		_dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_dust_mat.vertex_color_use_as_albedo = true
		_dust_mat.albedo_color = Color(0.45, 0.4, 0.33, 0.35)
		_dust_mat.albedo_texture = load("res://Effects/Files/TX_Smoke.png")
	return _dust_mat


# The crack and crash: the game's own wood (or metal) hits, one on another.
static func _crash(scene: Node, at: Vector3, metal: bool) -> void:
	var lib = load("res://Resources/AudioLibrary.tres")
	if lib == null:
		return
	var events := [[0.0, lib.hitMetal if metal else lib.hitWood], [0.08, lib.hitMetal if metal else lib.hitWood], [0.2, lib.knifeHitMetal if metal else lib.knifeHitWood]]
	for e in events:
		if e[1] == null:
			continue                                   # never play a missing event
		if e[0] <= 0.0:
			_sound(scene, at, e[1])
		else:
			scene.get_tree().create_timer(e[0], false).timeout.connect(func():
				if is_instance_valid(scene):
					_sound(scene, at, e[1]))


static func _sound(scene: Node, at: Vector3, event) -> void:
	var a = load("res://Resources/AudioInstance3D.tscn").instantiate()
	scene.add_child(a)
	a.global_position = at
	a.PlayInstance(event, 40, 50)


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
		piece.collision_layer = 256         # like the game's ragdolls: lands on every floor, walked through
		piece.collision_mask = 25
		piece.continuous_cd = true
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
	if att:
		_stump(att)
	var d = _dhe()
	if d:
		d.splatter(z, at, Vector3.DOWN, [])


# The stump keeps dripping for a while.
static func _stump(att: Node3D) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "CS_Stump"
	p.amount = 24
	p.lifetime = 0.9
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.DOWN
	pm.spread = 20.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0, -9.8, 0)
	pm.color = Color(0.7, 0.03, 0.03)
	p.process_material = pm
	var sm := SphereMesh.new()
	sm.radius = 0.007
	sm.height = 0.014
	sm.material = blood_material()
	p.draw_pass_1 = sm
	att.add_child(p)
	p.emitting = true
	att.get_tree().create_timer(randf_range(12.0, 25.0), false).timeout.connect(func():
		if is_instance_valid(p):
			p.emitting = false)
	return p


# ---------------------------------------------------------------- death

static func died(z, _vector: Vector3) -> void:
	if bool(setting("respawn")) and z.AISpawner and z.AISpawner.has_method("ZS_Replenish"):
		var sp = z.AISpawner
		z.get_tree().create_timer(randf_range(30.0, 90.0), false).timeout.connect(func():
			if is_instance_valid(sp):
				sp.ZS_Replenish())
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
	c.set("containerSize", Vector2(4, 6))
	c.set("corpse", true)
	# opening and closing play this; without one the game crashes
	c.set("audioEvent", load("res://Audio/Interaction/Container_Corpse.tres"))
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
