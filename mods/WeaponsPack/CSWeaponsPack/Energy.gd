# CleanStrike Weapons Pack: the Ray Gun's energy bolts. A shot is a glowing
# green-and-cyan bolt that flies to where you aimed, trailing plasma that
# hangs in the air for a moment; it hits when it arrives (through the game's
# own hit code: damage, blood, impacts), with a burst, a flash and a cloud of
# drifting plasma dust.
extends RefCounted

const SPEED := 32.0                       # metres a second: quick, and you see it fly
const CORE := Color(0.62, 1.0, 0.72)
const GLOW := Color(0.25, 0.95, 1.0)
const DEEP := Color(0.1, 0.55, 1.0)
const SOUNDS := "res://CSWeaponsPack/Sounds/"
const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float energy = 3.0;
uniform bool billboard = true;
uniform sampler2D tex : source_color, filter_linear_mipmap;
void vertex() {
	if (billboard) {
		mat4 m = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = VIEW_MATRIX * m * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	}
}
void fragment() {
	ALBEDO = tint.rgb * COLOR.rgb * energy;
	ALPHA = clamp(texture(tex, UV).a * tint.a * COLOR.a, 0.0, 1.0);
}
"""

const STREAK := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float energy = 3.0;
void fragment() {
	float along = clamp(UV.y, 0.0, 1.0);
	float edge = 1.0 - abs(UV.x * 2.0 - 1.0);
	ALBEDO = tint.rgb * energy;
	ALPHA = clamp(tint.a * pow(1.0 - along, 1.6) * (0.35 + 0.65 * edge), 0.0, 1.0);
}
"""

static var _streak: Shader
static var _shader: Shader
static var _tex: Texture2D
static var _hits: Array = []


static func release() -> void:
	_streak = null
	_shader = null
	_tex = null
	_hits.clear()


static func _mat(tint: Color, energy: float, billboard: bool) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_tex = gt
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("billboard", billboard)
	m.set_shader_parameter("tex", _tex)
	return m


# Glowing particles. o: explode, radius, dir, spread, v0, v1, gravity, damp,
# s0, s1, turb, alpha, energy.
static func _particles(amount: int, life: float, one_shot: bool, o: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = o.get("explode", 0.0)
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = o.get("radius", 0.02)
	pm.direction = o.get("dir", Vector3.UP)
	pm.spread = o.get("spread", 180.0)
	pm.initial_velocity_min = o.get("v0", 0.05)
	pm.initial_velocity_max = o.get("v1", 0.3)
	pm.gravity = o.get("gravity", Vector3(0, 0.12, 0))
	pm.damping_min = o.get("damp", 0.6)
	pm.damping_max = o.get("damp", 0.6) * 1.6
	pm.scale_min = o.get("s0", 0.03)
	pm.scale_max = o.get("s1", 0.07)
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.5))
	sc.add_point(Vector2(0.2, 1.0))
	sc.add_point(Vector2(1.0, o.get("end_size", 0.25)))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var a: float = o.get("alpha", 1.0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(CORE, a), Color(GLOW, a * 0.7), Color(DEEP, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	if o.get("turb", 0.0) > 0.0:
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = o.turb
		pm.turbulence_noise_scale = 1.6
		pm.turbulence_influence_min = 0.04
		pm.turbulence_influence_max = 0.14
	p.process_material = pm
	var q := QuadMesh.new()
	q.material = _mat(Color.WHITE, o.get("energy", 2.5), true)
	p.draw_pass_1 = q
	return p


static func _light(energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 1.0, 0.8)
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	return l


static func _halo(size: float, tint: Color, energy: float) -> MeshInstance3D:
	var h := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	h.mesh = q
	h.material_override = _mat(tint, energy, true)
	h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return h


static func _sound(parent: Node, at: Vector3, stream: AudioStream, db: float) -> void:
	if stream == null:
		return
	var s := AudioStreamPlayer3D.new()
	s.stream = stream
	s.bus = &"SFX"
	s.volume_db = db
	s.unit_size = 6.0
	s.max_distance = 70.0
	s.pitch_scale = randf_range(0.92, 1.08)
	parent.add_child(s)
	s.global_position = at
	s.play()
	s.finished.connect(s.queue_free)


static func hit_sound() -> AudioStream:
	if _hits.is_empty():
		for f in ["raygun_hit_1.wav", "raygun_hit_2.wav"]:
			_hits.append(AudioStreamWAV.load_from_buffer(FileAccess.get_file_as_bytes(SOUNDS + f)))
	return _hits.pick_random()


# A shot: the bolt leaves the muzzle for the point the gun is aimed at.
static func shot(rig: Node) -> Node3D:
	var ray: RayCast3D = rig.get("raycast")
	var tree := rig.get_tree()
	var world_parent: Node = tree.current_scene
	var from := ray.global_position
	var dir := (ray.global_transform.basis * ray.target_position).normalized()
	var length := ray.target_position.length()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * length, ray.collision_mask)
	q.collide_with_areas = ray.collide_with_areas
	q.collide_with_bodies = ray.collide_with_bodies
	var r: Dictionary = (rig as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
	var end: Vector3 = r.position if not r.is_empty() else from + dir * length
	var muzzle: Node3D = rig.get("muzzle")
	var start: Vector3 = muzzle.global_position if muzzle else from
	# muzzle burst
	var burst := Node3D.new()
	world_parent.add_child(burst)
	burst.global_position = start
	var sparks := _particles(18, 0.25, true, {"explode": 1.0, "dir": dir, "spread": 22.0, "v0": 1.0, "v1": 3.5, "s0": 0.015, "s1": 0.04, "gravity": Vector3.ZERO, "damp": 3.0})
	burst.add_child(sparks)
	sparks.emitting = true
	var flash := _halo(0.12, Color(GLOW, 0.8), 3.0)
	burst.add_child(flash)
	var fl := _light(3.0, 4.0)
	burst.add_child(fl)
	var tw := tree.create_tween()
	tw.tween_property(flash, "scale", Vector3.ONE * 0.1, 0.12)
	tw.parallel().tween_property(fl, "light_energy", 0.0, 0.15)
	tree.create_timer(0.6, false).timeout.connect(burst.queue_free)
	# the bolt
	var bolt := Node3D.new()
	bolt.name = "CS_RayBolt"
	world_parent.add_child(bolt)
	bolt.global_position = start
	if start.distance_to(end) > 0.01:
		bolt.look_at(end, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
	var core := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.022
	cm.height = 0.42
	core.mesh = cm
	core.rotation.x = PI / 2.0
	core.material_override = _mat(CORE, 6.0, false)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.add_child(core)
	var halo := _halo(0.24, Color(GLOW, 0.55), 2.4)
	bolt.add_child(halo)
	# the plasma tail: a tapered glow streaming behind, grown over the first metres
	if _streak == null:
		_streak = Shader.new()
		_streak.code = STREAK
	var tail := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = 0.0
	tc.bottom_radius = 0.045
	tc.height = 3.5
	tc.radial_segments = 10
	tc.rings = 1
	tail.mesh = tc
	var tm := ShaderMaterial.new()
	tm.shader = _streak
	tm.set_shader_parameter("tint", Color(GLOW, 0.75))
	tm.set_shader_parameter("energy", 3.0)
	tail.material_override = tm
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pivot := Node3D.new()
	bolt.add_child(pivot)
	pivot.add_child(tail)
	tail.rotation.x = -PI / 2.0                 # cylinder along +Z (behind the bolt)
	tail.position.z = 1.75
	pivot.scale = Vector3(1, 1, 0.01)
	var grow := tree.create_tween()
	grow.tween_property(pivot, "scale", Vector3.ONE, 3.5 / SPEED)
	bolt.add_child(_light(2.4, 5.0))
	var trail := _particles(360, 0.5, false, {"radius": 0.015, "v0": 0.02, "v1": 0.25, "s0": 0.012, "s1": 0.035, "turb": 0.45, "energy": 3.0})
	bolt.add_child(trail)
	var dust := _particles(110, 1.8, false, {"radius": 0.04, "v0": 0.02, "v1": 0.2, "s0": 0.05, "s1": 0.14, "turb": 0.8, "alpha": 0.22, "energy": 1.3, "end_size": 1.3, "gravity": Vector3(0, 0.05, 0)})
	bolt.add_child(dust)
	trail.emitting = true
	dust.emitting = true
	var t := start.distance_to(end) / SPEED
	var mv := tree.create_tween()
	mv.tween_property(bolt, "global_position", end, maxf(0.02, t))
	# the glow keeps its size on screen as it flies away
	halo.scale = Vector3.ONE * 0.5
	var swell := tree.create_tween()
	swell.tween_property(halo, "scale", Vector3.ONE * clampf(start.distance_to(end) / 8.0, 1.0, 4.0), maxf(0.02, t))
	swell.parallel().tween_property(core, "scale", Vector3.ONE * clampf(start.distance_to(end) / 12.0, 1.0, 2.5), maxf(0.02, t))
	var data: Resource = rig.get("data")
	var ident: Node = rig.get("identifier")
	var ref := weakref(rig)
	mv.tween_callback(func(): _land(bolt, ref, data, ident, from, dir, length, ray.collision_mask, ray.collide_with_areas, ray.collide_with_bodies, world_parent))
	return bolt


# The bolt arrives: the hit happens now (the target may have moved), then the
# burst, flash and dust; the trail is left to fade.
static func _land(bolt: Node3D, ref: WeakRef, data: Resource, ident: Node, from: Vector3, dir: Vector3, length: float, mask: int, areas: bool, bodies: bool, world_parent: Node) -> void:
	if not is_instance_valid(bolt):
		return
	for c in bolt.get_children():
		if c is GPUParticles3D:
			c.emitting = false
		elif c is VisualInstance3D or c is Light3D:
			c.visible = false
	bolt.get_tree().create_timer(1.7, false).timeout.connect(bolt.queue_free)
	if not is_instance_valid(world_parent):
		return
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * length, mask)
	q.collide_with_areas = areas
	q.collide_with_bodies = bodies
	var r: Dictionary = bolt.get_world_3d().direct_space_state.intersect_ray(q)
	var at: Vector3 = bolt.global_position
	var normal := -dir
	if not r.is_empty():
		at = r.position
		normal = r.normal
		var col: Object = r.collider
		var rig = ref.get_ref()
		var who: Node = ident if is_instance_valid(ident) else null
		if col is Hitbox:
			if data.has_meta("cs_head_damage"):
				Engine.set_meta("cs_head_damage", data.get_meta("cs_head_damage"))
			col.ApplyDamage(data.damage, dir, who)
			if Engine.has_meta("cs_head_damage"):
				Engine.remove_meta("cs_head_damage")
			if rig:
				rig.BloodEffect(col, at, normal)
		elif col is Node and col.owner is Mine:
			col.owner.InstantDetonate()
		elif col is Pickup and col.slotData.itemData.type == "Grenade":
			col.Explode()
		elif rig:
			rig.HitEffect(col, at, normal, col.get("surface"))
	impact(world_parent, at, normal)


static func impact(world_parent: Node, at: Vector3, normal: Vector3) -> void:
	var n := Node3D.new()
	n.name = "CS_RayImpact"
	world_parent.add_child(n)
	n.global_position = at + normal * 0.03
	var sparks := _particles(70, 0.55, true, {"explode": 1.0, "dir": normal, "spread": 75.0, "v0": 2.0, "v1": 6.5, "gravity": Vector3(0, -2.5, 0), "s0": 0.02, "s1": 0.05, "damp": 2.0, "energy": 3.5})
	var cloud := _particles(60, 2.6, true, {"explode": 0.85, "dir": normal, "spread": 130.0, "radius": 0.1, "v0": 0.3, "v1": 1.1, "s0": 0.18, "s1": 0.5, "turb": 0.8, "alpha": 0.32, "energy": 1.6, "end_size": 1.4, "gravity": Vector3(0, 0.1, 0), "damp": 1.2})
	n.add_child(sparks)
	n.add_child(cloud)
	sparks.emitting = true
	cloud.emitting = true
	var ring := _halo(0.35, Color(GLOW, 0.9), 4.0)
	n.add_child(ring)
	var light := _light(8.0, 8.0)
	n.add_child(light)
	var tw := n.get_tree().create_tween()
	tw.tween_property(ring, "scale", Vector3.ONE * 6.0, 0.28).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "transparency", 1.0, 0.25)
	tw.parallel().tween_property(light, "light_energy", 0.0, 0.4)
	_sound(n, at, hit_sound(), 2.0)
	n.get_tree().create_timer(3.0, false).timeout.connect(n.queue_free)
