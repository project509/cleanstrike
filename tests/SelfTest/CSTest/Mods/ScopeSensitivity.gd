# Self-test for Scope Sensitivity (cs_scope_sensitivity). r is the CSTest runner.
extends RefCounted

const SS = preload("res://CSScopeSensitivity/Mod.gd")


func run(r) -> void:
	r.check("ScopeSensitivity: active", SS.active())
	var k := SS.factor(15.0, 70.0)
	r.check("ScopeSensitivity: slower when magnified", absf(k - tan(deg_to_rad(7.5)) / tan(deg_to_rad(35.0))) < 0.001, "%.3f" % k)
	r.check("ScopeSensitivity: unchanged at normal view", SS.factor(70.0, 70.0) == 1.0)
	var gd = load("res://Resources/GameData.tres")
	var ctrl = r.get_node("/root/Map/Core/Controller")
	var keep := [gd.isAiming, gd.isScoped, gd.PIP, gd.aimFOV]
	gd.PIP = false
	gd.isAiming = true
	gd.isScoped = true
	gd.aimFOV = 15.0
	var scoped := _turn(ctrl, 100.0)
	SS.overrides = {"strength": 0.0}
	var game := _turn(ctrl, 100.0)
	SS.overrides = {}
	r.check("ScopeSensitivity: mouse slows through a scope", game != 0.0 and absf(scoped / game - k) < 0.02, "%.3f vs %.3f" % [scoped / game if game != 0.0 else 0.0, k])
	gd.isAiming = keep[0]
	gd.isScoped = keep[1]
	gd.PIP = keep[2]
	gd.aimFOV = keep[3]


func _turn(ctrl, dx: float) -> float:
	var before: float = ctrl.rotation_degrees.y
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(dx, 0.0)
	ctrl._input(ev)
	var turned: float = ctrl.rotation_degrees.y - before
	ctrl.rotation_degrees.y = before
	return turned
