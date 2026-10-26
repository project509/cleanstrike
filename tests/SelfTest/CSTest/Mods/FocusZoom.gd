# Self-test for Focus Zoom (cs_focus_zoom). r is the CSTest runner.
extends RefCounted

const FZ = preload("res://CSFocusZoom/Mod.gd")


func run(r) -> void:
	r.check("FocusZoom: active", FZ.active())
	var gd = load("res://Resources/GameData.tres")
	var cam = r.get_node_or_null("/root/Map/Core/Camera")
	r.check("FocusZoom: camera uses the mod", cam != null and "fz_was_down" in cam)
	if cam == null or not ("fz_was_down" in cam):
		return
	var base: float = gd.baseFOV
	gd.aimFOV = base
	await r.wait(0.6)
	r.check("FocusZoom: no zoom without the key", absf(cam.camera.fov - base) < 1.0, "%.1f" % cam.camera.fov)

	FZ.overrides = {"held": true}
	await r.wait(0.8)
	r.check("FocusZoom: focus zooms 1.8x", absf(cam.camera.fov - base / 1.8) < 1.0, "%.1f (want %.1f)" % [cam.camera.fov, base / 1.8])

	# Mouse look slows with the zoom
	var ctrl = r.get_node("/root/Map/Core/Controller")
	var view = cam.get_viewport().get_camera_3d()
	var k := FZ.sensitivity_factor(view.fov, base) if view else 1.0
	var turned := _turn(ctrl, 100.0)
	FZ.overrides = {"held": false}
	await r.wait(0.8)
	var plain := _turn(ctrl, 100.0)
	r.check("FocusZoom: mouse slows with the zoom", plain != 0.0 and absf(turned / plain - k) < 0.05 and k < 0.9, "ratio %.3f vs %.3f" % [turned / plain if plain != 0.0 else 0.0, k])

	# Sprinting (the game clears isRunning every frame when you aren't): the maths
	var sprinting := {"isAiming": false, "isRunning": true, "isScoped": false, "aimFOV": base, "baseFOV": base}
	var sprint_fov := FZ.target_fov(sprinting, base, true)
	r.check("FocusZoom: lighter zoom while sprinting", absf(sprint_fov - base / 1.3) < 0.1, "%.1f" % sprint_fov)
	FZ.overrides = {"held": true}

	gd.interface = true
	await r.wait(0.8)
	r.check("FocusZoom: no zoom with the inventory open", absf(cam.camera.fov - base) < 1.0, "%.1f" % cam.camera.fov)
	gd.interface = false

	# Aiming: iron sights get the ADS zoom; magnified scopes are left alone
	FZ.overrides = {"held": false}
	gd.isAiming = true
	await r.wait(0.8)
	r.check("FocusZoom: ADS zoom on iron sights", absf(cam.camera.fov - base / 1.2) < 1.0, "%.1f" % cam.camera.fov)
	gd.isScoped = true
	gd.aimFOV = base - 25.0
	FZ.overrides = {"held": true}
	await r.wait(0.8)
	r.check("FocusZoom: magnified scopes unchanged", absf(cam.camera.fov - (base - 25.0)) < 1.0, "%.1f" % cam.camera.fov)
	gd.isScoped = false
	gd.isAiming = false
	gd.aimFOV = base

	# Toggle mode: press once to focus, again to stop
	FZ.overrides = {"toggle": true, "held": false}
	await r.wait(0.1)
	FZ.overrides = {"toggle": true, "held": true}
	await r.wait(0.1)
	FZ.overrides = {"toggle": true, "held": false}
	await r.wait(0.8)
	var on: float = cam.camera.fov
	FZ.overrides = {"toggle": true, "held": true}
	await r.wait(0.1)
	FZ.overrides = {"toggle": true, "held": false}
	await r.wait(0.8)
	r.check("FocusZoom: toggle mode", absf(on - base / 1.8) < 1.5 and absf(cam.camera.fov - base) < 1.0, "%.1f then %.1f" % [on, cam.camera.fov])
	FZ.overrides = {}
	FZ.toggled = false


# Turn the player with a mouse movement; returns degrees turned (and turns back).
func _turn(ctrl, dx: float) -> float:
	var before: float = ctrl.rotation_degrees.y
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(dx, 0.0)
	ctrl._input(ev)
	var turned: float = ctrl.rotation_degrees.y - before
	ctrl.rotation_degrees.y = before
	return turned
