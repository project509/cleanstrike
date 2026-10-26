# Self-test for Airdrops (cs_airdrops). r is the CSTest runner.
extends RefCounted

const AD = preload("res://CSAirdrops/Mod.gd")


func run(r) -> void:
	r.check("Airdrops: active", AD.active())
	var plane = load("res://Assets/CASA/CASA.tscn").instantiate()
	r.check("Airdrops: plane uses the mod", plane.has_method("AD_MarkLanded"))
	if not plane.has_method("AD_MarkLanded"):
		plane.free()
		return
	plane.process_mode = Node.PROCESS_MODE_DISABLED   # keep it parked
	r.get_tree().current_scene.add_child(plane)
	await r.wait(0.1)
	plane.AD_MarkLanded()
	var smoke = plane.airdrop.get_node_or_null("CS_RedSmoke")
	r.check("Airdrops: red smoke from the crate", smoke != null and smoke.emitting and smoke.process_material.color_ramp.gradient.get_color(0).r > 0.7)
	r.check("Airdrops: red glow", smoke != null and smoke.get_node_or_null("CS_RedGlow") != null)
	plane.queue_free()
