# Self-test for Hold Breath (cs_hold_breath). r is the CSTest runner.
extends RefCounted

const HB = preload("res://CSHoldBreath/Mod.gd")


func run(r) -> void:
	r.check("HoldBreath: active", HB.active())
	var hooked := false
	var s = load("res://Scripts/Noise.gd")
	while s:
		if s.get_script_constant_map().has("HB"):
			hooked = true
		s = s.get_base_script()
	r.check("HoldBreath: weapon sway hook installed", hooked)
	var gd = load("res://Resources/GameData.tres")
	var stamina: float = gd.armStamina

	# The breath, step by step
	gd.isAiming = true
	gd.isRunning = false
	gd.armStamina = 100.0
	HB.reset()
	HB.overrides = {"held": true}
	for i in 60:
		HB.step(gd, 1.0 / 60.0)
	r.check("HoldBreath: steadies the aim", HB.holding and HB.sway < 0.3, "sway %.2f" % HB.sway)
	r.check("HoldBreath: tires the arms", absf(gd.armStamina - 92.0) < 0.5, "%.1f arm stamina" % gd.armStamina)
	HB.overrides = {"held": true, "max_hold": 2.0}
	for i in 120:
		HB.step(gd, 1.0 / 60.0)
	r.check("HoldBreath: runs out, then catches breath", not HB.holding and HB.gasping and HB.sway > 1.4, "sway %.2f" % HB.sway)
	for i in 60:
		HB.step(gd, 1.0 / 60.0)
	r.check("HoldBreath: can't hold again while recovering", not HB.holding)
	for i in 180:
		HB.step(gd, 1.0 / 60.0)
	r.check("HoldBreath: holds again after recovering", HB.holding)
	HB.overrides = {"held": false}
	HB.step(gd, 1.0 / 60.0)
	r.check("HoldBreath: letting go is quick to recover", not HB.holding and HB.recovering > 0.0 and HB.recovering < 3.0, "%.2f s" % HB.recovering)

	# A real weapon-sway node: less sway while holding
	HB.reset()
	gd.armStamina = 100.0
	var node := Node3D.new()
	node.set_script(load("res://Scripts/Noise.gd"))
	node.noise = FastNoiseLite.new()
	r.get_tree().current_scene.add_child(node)
	# The game sets rotation = its noise; the hook scales it by the breath.
	HB.overrides = {"held": false, "aiming": true}
	await r.wait(0.3)
	var loose := _ratio(node)
	HB.overrides = {"held": true, "aiming": true}
	await r.wait(0.6)
	var steady := _ratio(node)
	r.check("HoldBreath: real weapon sways less", absf(loose - 1.0) < 0.05 and steady < 0.35 and HB.holding, "%.2f x the game's sway (was %.2f)" % [steady, loose])
	node.queue_free()
	HB.overrides = {}
	HB.reset()
	gd.isAiming = false
	gd.armStamina = stamina


func _ratio(node) -> float:
	var raw: float = node.weaponNoise.length()
	return node.rotation.length() / raw if raw > 0.0 else -1.0
