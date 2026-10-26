# Self-test for Immortal Cat (cs_immortal_cat). r is the CSTest runner.
extends RefCounted

const IC = preload("res://CSImmortalCat/Mod.gd")


func run(r) -> void:
	r.check("ImmortalCat: active", IC.active())
	var gd = load("res://Resources/GameData.tres")
	var saved := [gd.catFound, gd.catDead, gd.cat]
	var ch = r.get_node("/root/Map/Core/Controller/Character")
	gd.catFound = true
	gd.catDead = false
	gd.cat = 0.5
	for i in 600:
		ch.Cat(1.0 / 60.0)
	r.check("ImmortalCat: an empty bowl doesn't kill the cat", not gd.catDead and gd.cat >= 1.0, "%.2f" % gd.cat)
	IC.overrides = {"never_hungry": true}
	ch.Cat(1.0 / 60.0)
	r.check("ImmortalCat: never hungry option", gd.cat > 99.9)
	IC.overrides = {}
	gd.catFound = saved[0]
	gd.catDead = saved[1]
	gd.cat = saved[2]
