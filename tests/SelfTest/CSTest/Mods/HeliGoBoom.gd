# Self-test for Heli Go Boom (cs_heli_go_boom). r is the CSTest runner.
extends RefCounted

const HB = preload("res://CSHeliGoBoom/Mod.gd")


func run(r) -> void:
	r.check("HeliGoBoom: active", HB.active())
	var sys := Node3D.new()
	sys.set_script(load("res://Scripts/EventSystem.gd"))
	var spots := Node3D.new()
	var spot := Node3D.new()
	spots.add_child(spot)
	sys.add_child(spots)
	sys.crashes = spots
	r.get_tree().current_scene.add_child(sys)
	HB.overrides = {"max_delay": 0}
	HB.last_boom = ""
	await sys.CrashSite()
	r.check("HeliGoBoom: crash site placed", spot.get_child_count() == 1)
	r.check("HeliGoBoom: you hear it", HB.last_boom != "", HB.last_boom)
	HB.overrides = {}
	sys.queue_free()
