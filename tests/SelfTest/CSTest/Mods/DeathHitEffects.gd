# Self-test for Death and Hit Effects (cs_death_hit_effects). r is the CSTest runner.
extends RefCounted

const DHE = preload("res://CSDeathHitEffects/Mod.gd")


func _hooked(path: String) -> bool:
	var s = load(path)
	while s:
		if s.get_script_constant_map().has("DHE"):
			return true
		s = s.get_base_script()
	return false


func run(r) -> void:
	r.check("DeathHitEffects: active", DHE.active())
	r.check("DeathHitEffects: AI death hook", _hooked("res://Scripts/AI.gd"))
	var player = r.get_node("/root/Map/Core/Controller")
	var world: Node3D = player
	var feet: Vector3 = player.global_position
	var splat := DHE.splatter(world, feet + Vector3.UP * 1.0, Vector3.DOWN, [player.get_rid()])
	r.check("DeathHitEffects: splatter lands on the floor", splat != null and splat.global_position.y < feet.y + 0.5 and splat.global_basis.y.dot(Vector3.UP) > 0.9)
	var body := Node3D.new()
	r.get_tree().current_scene.add_child(body)
	body.global_position = feet + Vector3(1.5, 0.3, 0)
	DHE.overrides = {"pool_seconds": 0.5}
	var pool := DHE.pool(body)
	var t := 0.0
	while pool and pool.size.x < 1.5 and t < 5.0:   # a slow frame in the suite must not fail it
		await r.wait(0.1)
		t += 0.1
	r.check("DeathHitEffects: a pool spreads under a body", pool != null and pool.size.x > 1.4, str(pool.size if pool else ""))
	DHE.overrides = {"max_decals": 1}
	var extra := DHE.place(r.get_tree().current_scene, feet, Vector3.UP, 0.5, "splat")
	await r.wait(0.1)
	r.check("DeathHitEffects: old marks are cleared", DHE.decals.size() == 1 and DHE.decals[0] == extra)
	var tex: Image = DHE.texture("splat").get_image()
	r.check("DeathHitEffects: blood is dark red", tex.get_pixel(128, 128).r > tex.get_pixel(128, 128).g * 3.0 and tex.get_pixel(128, 128).r < 0.3 and tex.get_pixel(128, 128).a > 0.5)
	var m = DHE.marker(r.get_tree(), true)
	r.check("DeathHitEffects: kill marker shows", m != null and m.kill and m.t < m.LIFE)
	await r.wait(0.6)
	r.check("DeathHitEffects: marker fades", m.t >= m.LIFE)
	DHE.overrides = {}
	for d in DHE.decals:
		if is_instance_valid(d):
			d.queue_free()
	body.queue_free()
