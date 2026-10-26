# Self-test for CleanStrike HUD (cs_hud). r is the CSTest runner.
extends RefCounted

const H = preload("res://CSHUD/Mod.gd")


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


func run(r) -> void:
	r.check("HUD: active", H.active())
	var hud = r.get_node("/root/Map/Core/UI/HUD")
	var o = hud.get_node_or_null("CS_HUD")
	r.check("HUD: overlay on the game HUD", o != null)
	if o == null:
		return
	await r.wait(0.3)
	r.check("HUD: game vitals text replaced", not hud.vitals.visible)
	var cam = r.get_viewport().get_camera_3d()
	var keep = cam.global_rotation
	var h1: float = o.heading()
	cam.global_rotation.y -= deg_to_rad(90.0)    # turn right
	var h2: float = o.heading()
	cam.global_rotation = keep
	r.check("HUD: compass follows the view", absf(wrapf(h2 - h1, -180.0, 180.0) - 90.0) < 1.0, "%.1f -> %.1f" % [h1, h2])
	var dot := H.dot_on
	hud._unhandled_input(_key(KEY_O))
	r.check("HUD: O toggles the centre dot", H.dot_on != dot)
	hud._unhandled_input(_key(KEY_O))
	hud._unhandled_input(_key(KEY_F2))
	await r.wait(0.2)
	r.check("HUD: F2 hides the HUD", not o.visible and not hud.stats.visible)
	hud._unhandled_input(_key(KEY_F2))
	await r.wait(0.2)
	r.check("HUD: F2 brings it back", o.visible and hud.stats.visible)
