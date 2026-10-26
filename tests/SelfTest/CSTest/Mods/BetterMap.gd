# Self-test for Better Map (cs_better_map). r is the CSTest runner.
extends RefCounted

const BM = preload("res://CSBetterMap/Mod.gd")


func run(r) -> void:
	r.check("BetterMap: active", BM.active())
	var interface = r.get_node("/root/Map/Core/UI/Interface")
	r.check("BetterMap: map hook installed", "BM" in interface.get_script().get_script_constant_map() or interface.get_script().get_base_script() != null)
	var o = BM.show_on(interface.mapScroll.map)
	r.check("BetterMap: overlay on the world map", o != null and o.get_parent() == interface.mapScroll.map)
	r.check("BetterMap: player located", BM.where()[0] == "Tutorial")
	var lines := BM.lines()
	var village: Array = lines.get("Village", [])
	r.check("BetterMap: shelters listed by area", village.has(["shelter", "Attic"]) and village.has(["shelter", "Cabin"]) and lines.get("Outpost", []).has(["shelter", "Bunker"]))
	var saved: Dictionary = BM.met().duplicate()
	BM.met()["Doctor"] = "Outpost"
	r.check("BetterMap: met traders listed", BM.lines().get("Outpost", []).has(["trader", "Doctor"]))
	BM.meet("Generalist")
	r.check("BetterMap: tutorial traders aren't recorded", BM.met().get("Generalist", "") != "Tutorial")
	BM._met = saved
	r.check("BetterMap: every listed area has a marker", lines.keys().all(func(a): return interface.mapScroll.map.get_node_or_null(a) != null))
	o.here = "Village"
	o.here_label = "You"
	o.queue_redraw()
	await r.wait(0.1)
	r.check("BetterMap: draws without errors", is_instance_valid(o))
	o.queue_free()
