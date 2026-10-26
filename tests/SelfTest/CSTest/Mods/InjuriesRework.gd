# Self-test for Injuries Rework (cs_injuries_rework). r is the CSTest runner.
extends RefCounted

const IR = preload("res://CSInjuriesRework/Mod.gd")
const FLAGS := ["bleeding", "fracture", "rupture", "headshot", "burn", "starvation", "dehydration", "insanity", "frostbite", "poisoning"]


func _clean(gd) -> void:
	for f in FLAGS:
		gd.set(f, false)
	gd.health = 100.0
	gd.energy = 100.0
	gd.hydration = 100.0
	gd.isRunning = false


func run(r) -> void:
	r.check("InjuriesRework: active", IR.active())
	var gd = load("res://Resources/GameData.tres")
	var ch = r.get_node("/root/Map/Core/UI/Interface").character
	r.check("InjuriesRework: character uses the mod", ch.has_method("Health") and "ir_bleed" in ch)
	if not ("ir_bleed" in ch):
		return
	var before := {}
	for k in ["health", "energy", "hydration", "bodyStamina", "armStamina", "mental"]:
		before[k] = gd.get(k)
	_clean(gd)
	ch.process_mode = Node.PROCESS_MODE_DISABLED   # only our ticks below

	gd.bleeding = true
	ch.Health(1.0)
	r.check("InjuriesRework: bleeding hurts more", absf(gd.health - 99.5) < 0.01, "%.2f" % gd.health)
	ch.ir_bleed = 29.5
	ch.Health(1.0)
	r.check("InjuriesRework: a bleed stops by itself", not gd.bleeding)

	_clean(gd)
	gd.fracture = true
	ch.Health(1.0)
	var walking: float = 100.0 - gd.health
	gd.health = 100.0
	gd.isRunning = true
	ch.Health(1.0)
	r.check("InjuriesRework: running on a fracture hurts", (100.0 - gd.health) > walking + 1.5, "%.2f vs %.2f" % [100.0 - gd.health, walking])

	_clean(gd)
	gd.rupture = true
	ch.Health(1.0)
	r.check("InjuriesRework: rupture: no health drain", gd.health == 100.0)
	r.check("InjuriesRework: rupture: hungry and thirsty", gd.energy < 100.0 and gd.hydration < 100.0)

	_clean(gd)
	gd.bodyStamina = 100.0
	gd.armStamina = 100.0
	ch.Headshot(true)
	ch.Health(1.0)
	ch.Stamina(0.5)
	r.check("InjuriesRework: headshot doesn't drain health", gd.health == 100.0 and not gd.bleeding)
	r.check("InjuriesRework: headshot: dazed", gd.bodyStamina == 0.0 and gd.armStamina < 100.0)

	_clean(gd)
	ch.process_mode = Node.PROCESS_MODE_INHERIT
	for k in before:
		gd.set(k, before[k])
