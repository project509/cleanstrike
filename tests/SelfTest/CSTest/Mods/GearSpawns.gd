# Self-test for Gear Spawns (cs_gear_spawns). r is the CSTest runner.
extends RefCounted

const GS = preload("res://CSGearSpawns/Mod.gd")


func run(r) -> void:
	r.check("GearSpawns: active", GS.active())
	var hooked := 0
	# Class scripts (LootContainer) are swapped onto nodes, so look at a real one.
	var box = null
	for n in r.get_tree().current_scene.find_children("*", "", true, false):
		if n is LootContainer:
			box = n
			break
	for first in [load("res://Scripts/AI.gd"), load("res://Scripts/Sensor.gd"), box.get_script() if box else null, load("res://Scripts/LootSimulation.gd")]:
		var s = first
		while s:
			if s.get_script_constant_map().has("GS"):
				hooked += 1
				break
			s = s.get_base_script()
	r.check("GearSpawns: hooks installed (AI, sight, containers, floor)", hooked == 4, str(hooked))

	var sim = r.get_node("/root/Simulation")
	var day: int = sim.day
	sim.day = 1
	r.check("GearSpawns: suppressors rare before their day", GS.chance("military", "Muzzle") == 2.0)
	sim.day = 40
	r.check("GearSpawns: faction chances after unlock", GS.chance("military", "Muzzle") == 20.0 and GS.chance("bandit", "Optic") == 10.0)

	var akm = load("res://Items/Weapons/AKM/AKM.tres")
	GS.overrides = {"military_scope": 100, "military_suppressor": 100, "military_laser": 100}
	var got := GS.roll_attachments(akm, "military", [])
	var kinds := got.map(func(a): return str(a.subtype))
	var ok := kinds.size() == kinds.duplicate().filter(func(k): return true).size()
	for k in kinds:
		ok = ok and kinds.count(k) == 1 and akm.compatible.has(got[kinds.find(k)])
	r.check("GearSpawns: one of each kind, all compatible", ok and kinds.size() >= 1, str(kinds))
	r.check("GearSpawns: nothing it already has", GS.roll_attachments(akm, "military", ["Optic", "Muzzle", "Laser"]).is_empty())

	GS.overrides = {"world_magazine": 100, "magazine_fill_min": 50, "magazine_fill_max": 50, "world_scope": 0, "world_suppressor": 0, "world_laser": 0}
	var sd := SlotData.new()
	sd.itemData = akm
	GS.kit_found_weapon(sd)
	r.check("GearSpawns: found gun gets a half-full magazine", sd.nested.has(akm.compatible[0]) and sd.amount == int(round(akm.magazineSize * 0.5)), "%d rounds" % sd.amount)
	GS.overrides = {}
	sim.day = day
