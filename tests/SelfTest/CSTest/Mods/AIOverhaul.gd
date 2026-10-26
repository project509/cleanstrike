# Self-test for AI Overhaul (cs_ai_overhaul). r is the CSTest runner.
extends RefCounted

const AO = preload("res://CSAIOverhaul/Mod.gd")
const FAKE_AI := "extends Node3D\nvar variant\n"


func _hooked(path: String) -> bool:
	var s = load(path)
	while s:
		if s.get_script_constant_map().has("AO") or s.get_script_constant_map().has("AOS"):
			return true
		s = s.get_base_script()
	return false


func run(r) -> void:
	r.check("AIOverhaul: active", AO.active())
	r.check("AIOverhaul: AI and sensor hooks", _hooked("res://Scripts/AI.gd") and _hooked("res://Scripts/Sensor.gd"))
	# Spread lies across the line of fire, equally wide both ways, whatever the facing
	var ok := true
	for dir in [Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0.6, 0.1, 0.8), Vector3(-1, 0.3, 0)]:
		var from := Vector3(5, 1, 5)
		var target: Vector3 = from + dir.normalized() * 40.0
		var along := 0.0
		var w := 0.0
		for i in 200:
			var off: Vector3 = AO.spread_point(from, target, 0.5) - target
			along = maxf(along, absf(off.dot(dir.normalized())))
			w = maxf(w, off.length())
		ok = ok and along < 0.001 and w > 0.45 and w <= 0.71
	r.check("AIOverhaul: spread across the line of fire in every direction", ok)
	r.check("AIOverhaul: military aim tighter than bandits", AO.spread_mult(3) < AO.spread_mult(2) and AO.spread_mult(2) < AO.spread_mult(1))
	# A guard's sensor in a storm, then with you crouched
	var s := GDScript.new()
	s.source_code = FAKE_AI
	s.reload()
	var me := Node3D.new()
	me.set_script(s)
	var data := AIData.new()
	data.faction = 2
	me.variant = data
	r.get_tree().current_scene.add_child(me)
	var sensor := MeshInstance3D.new()
	sensor.set_script(load("res://Scripts/Sensor.gd"))
	me.add_child(sensor)
	sensor.owner = me
	var gd = load("res://Resources/GameData.tres")
	var sim = r.get_node("/root/Simulation")
	var keep_w = sim.weather
	sim.weather = "Neutral"
	sensor.Visibility(0.01)
	sensor.AO_Scale()
	var clear: float = sensor.viewDistance
	sim.weather = "Storm"
	sensor.Visibility(0.01)
	sensor.AO_Scale()
	r.check("AIOverhaul: storms hide you", absf(sensor.viewDistance - clear * 0.7) < 0.5 and clear > 0.0, "%.0f -> %.0f" % [clear, sensor.viewDistance])
	var hear: float = sensor.hearDistance
	gd.isCrouching = true
	sensor.Visibility(0.01)
	sensor.AO_Scale()
	r.check("AIOverhaul: crouching is quieter", absf(sensor.hearDistance - hear * 0.6) < 0.01)
	gd.isCrouching = false
	sim.weather = keep_w
	me.queue_free()
