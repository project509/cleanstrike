# Self-test for Better Lean (cs_better_lean). r is the CSTest runner.
extends RefCounted

const BL = preload("res://CSBetterLean/Mod.gd")


func run(r) -> void:
	r.check("BetterLean: active", BL.active())
	var lean = null
	for n in r.get_tree().current_scene.find_children("*", "Node3D", true, false):
		if n.get_script() and "leanLToggle" in n:
			lean = n
			break
	r.check("BetterLean: found the lean node", lean != null)
	if lean == null:
		return
	var gd = load("res://Resources/GameData.tres")
	var mode: int = gd.leanMode
	gd.leanMode = 2
	lean.leanLToggle = true
	await r.wait(1.0)
	r.check("BetterLean: leans further", absf(lean.position.x + 0.35) < 0.03 and absf(lean.rotation_degrees.z - 15.0) < 1.0, "%.2f m, %.1f deg" % [lean.position.x, lean.rotation_degrees.z])
	gd.isRunning = true
	lean._physics_process(1.0 / 60.0)
	r.check("BetterLean: sprinting ends a toggled lean", not lean.leanLToggle)
	gd.isRunning = false
	gd.leanMode = mode
