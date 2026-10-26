# Self-test for Faction Warfare (cs_faction_warfare). r is the CSTest runner.
extends RefCounted

const FW = preload("res://CSFactionWarfare/Mod.gd")
const FAKE_AI := "extends Node3D\nvar variant\nvar active = true\nvar dead = false\nvar currentState = 0\nvar State = {\"Ambush\": 99}\n"

var made := []


# A stand-in AI of a faction, with its ID node in the "AI" group.
func _ai(r, faction: int) -> Node3D:
	var s := GDScript.new()
	s.source_code = FAKE_AI
	s.reload()
	var a := Node3D.new()
	a.set_script(s)
	var data := AIData.new()
	data.faction = faction
	a.variant = data
	var id := Node3D.new()
	id.add_to_group("Nomad" if faction == FW.NOMAD else "AI")
	a.add_child(id)
	id.owner = a
	r.get_tree().current_scene.add_child(a)
	made.append(a)
	return a


func _ids(sensor) -> Array:
	return sensor.targets.map(func(t): return t.owner.variant.faction if t.owner and "variant" in t.owner else -1)


func run(r) -> void:
	r.check("FactionWarfare: active", FW.active())
	r.check("FactionWarfare: rivals fight", FW.hostile(FW.BANDIT, FW.GUARD) and FW.hostile(FW.GUARD, FW.MILITARY) and FW.hostile(FW.MILITARY, FW.BANDIT))
	r.check("FactionWarfare: infighting defaults", FW.hostile(FW.BANDIT, FW.BANDIT) and not FW.hostile(FW.GUARD, FW.GUARD) and not FW.hostile(FW.MILITARY, FW.MILITARY))
	r.check("FactionWarfare: nomads as in the game", FW.hostile(FW.NOMAD, FW.GUARD) and not FW.hostile(FW.NOMAD, FW.NOMAD))
	var me := _ai(r, FW.GUARD)
	_ai(r, FW.BANDIT)
	_ai(r, FW.MILITARY)
	_ai(r, FW.GUARD)
	var sensor := MeshInstance3D.new()
	sensor.set_script(load("res://Scripts/Sensor.gd"))
	me.add_child(sensor)
	sensor.owner = me
	sensor.Targets()
	var ids := _ids(sensor)
	r.check("FactionWarfare: a guard targets bandits and military", ids.has(FW.BANDIT) and ids.has(FW.MILITARY), str(ids))
	r.check("FactionWarfare: but not other guards", not ids.has(FW.GUARD))
	r.check("FactionWarfare: neutral: you are a target", sensor.targets.any(func(t): return t.is_in_group("Player")))
	FW.overrides = {"side": "Guard"}
	sensor.Targets()
	r.check("FactionWarfare: siding with guards: they leave you alone", not sensor.targets.any(func(t): return t.is_in_group("Player")) and not sensor.PlayerValid())
	FW.overrides = {}
	var hooked := false
	var sc = load("res://Scripts/AISpawner.gd")
	while sc:
		hooked = hooked or sc.get_script_constant_map().has("FW")
		sc = sc.get_base_script()
	r.check("FactionWarfare: spawner hook installed", hooked)
	# A real spawner with a small bandit pool: rivals mix in
	var sp = load("res://Resources/AISpawner.tscn").instantiate()
	sp.active = false
	r.get_tree().current_scene.add_child(sp)
	sp.global_position = Vector3(0, -500, 0)
	sp.enemy = sp.bandit
	sp.EPoolSize = 4
	sp.activeEnemyLimit = 2
	FW.overrides = {"rivals": 50, "density": 2.0}
	await sp.CreatePools()
	var kinds := {}
	for e in sp.EPool.get_children():
		var f: int = e.variants[0].faction
		kinds[f] = int(kinds.get(f, 0)) + 1
	r.check("FactionWarfare: rival guards mix into a bandit zone", kinds.get(FW.BANDIT, 0) == 8 and kinds.get(FW.GUARD, 0) == 4, str(kinds))
	r.check("FactionWarfare: more enemies at once", sp.activeEnemyLimit == 4)
	FW.overrides = {}
	sp.queue_free()
	for a in made:
		a.queue_free()
	made.clear()
