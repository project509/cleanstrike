# Self-test for Shelters (cs_shelters). r is the CSTest runner.
extends RefCounted

const SH = preload("res://CSShelters/Mod.gd")
const KEEP := ["shelter", "tutorial", "energy", "hydration", "mental", "health", "bleeding", "isRunning"]


func run(r) -> void:
	r.check("Shelters: active", SH.active())
	var gd = load("res://Resources/GameData.tres")
	var ch = r.get_node("/root/Map/Core/UI/Interface").character
	var keep := {}
	for k in KEEP:
		keep[k] = gd.get(k)
	ch.process_mode = Node.PROCESS_MODE_DISABLED
	gd.tutorial = false
	gd.bleeding = false
	# Outside, then inside a shelter
	gd.shelter = false
	gd.energy = 80.0
	ch.Energy(30.0)
	var outside: float = 80.0 - gd.energy
	gd.shelter = true
	gd.energy = 80.0
	ch.Energy(30.0)
	var inside: float = 80.0 - gd.energy
	r.check("Shelters: hunger slows to a quarter inside", outside > 0.0 and absf(inside - outside * 0.25) < 0.001, "%.3f vs %.3f" % [inside, outside])
	gd.mental = 60.0
	ch.Mental(30.0)
	r.check("Shelters: no stress inside", gd.mental >= 60.0)
	gd.health = 50.0
	gd.energy = 80.0
	gd.hydration = 80.0
	ch.Health(60.0)
	r.check("Shelters: healing while safe", absf(gd.health - 56.0) < 0.01, "%.2f" % gd.health)
	gd.health = 50.0
	gd.bleeding = true
	ch.Health(10.0)
	r.check("Shelters: no healing while bleeding", gd.health < 50.0)
	for k in keep:
		gd.set(k, keep[k])
	ch.process_mode = Node.PROCESS_MODE_INHERIT
