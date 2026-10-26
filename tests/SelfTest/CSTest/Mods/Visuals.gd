# Self-test for Visuals (cs_visuals). r is the CSTest runner.
extends RefCounted

const V = preload("res://CSVisuals/Mod.gd")


func run(r) -> void:
	r.check("Visuals: active", V.active())
	var we = r.get_node_or_null("/root/Map/World/Environment")
	r.check("Visuals: map environment found", we != null and we.environment != null)
	for i in 3:
		await r.get_tree().process_frame
	var env: Environment = we.environment
	r.check("Visuals: colour grade applied", env.adjustment_enabled and env.adjustment_color_correction is ImageTexture3D)
	var mid := Color(0.5, 0.5, 0.5)
	r.check("Visuals: grey stays near grey (Tarkov)", absf(V.grade("Tarkov", mid).r - 0.5) < 0.06)
	var red := Color(0.8, 0.2, 0.2)
	var noir := V.grade("Noir", red)
	r.check("Visuals: Noir is black and white", absf(noir.r - noir.g) < 0.01)
	r.check("Visuals: Vivid is more colourful", V.grade("Vivid", red).r - V.grade("Vivid", red).g > red.r - red.g)
	var boot = r.get_node("/root/CSVisualsBoot")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_F3
	e.pressed = true
	boot._unhandled_input(e)
	r.check("Visuals: F3 shows the original", env.adjustment_color_correction == null)
	boot._unhandled_input(e)
	r.check("Visuals: F3 again grades", env.adjustment_color_correction != null)
	r.check("Visuals: sharpen pass over the 3D view", boot.layer.visible and boot.layer.layer < 0)
