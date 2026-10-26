# Self-test for Loot Settings (cs_loot_settings). r is the CSTest runner.
extends RefCounted

const LS = preload("res://CSLootSettings/Mod.gd")
const N := 4000


func run(r) -> void:
	r.check("LootSettings: active", LS.active())
	r.check("LootSettings: Balanced by default", LS.preset() == "Balanced", LS.preset())
	var common := []
	var rare := []
	var legendary := []
	for item in load("res://Loot/LT_Master.tres").items:
		if item and item.civilian:
			match int(item.rarity):
				0: common.append(item)
				1: rare.append(item)
				2: legendary.append(item)

	# The game's own maths (Custom with no extras): ~81% empty
	LS.overrides = {"preset": "Custom", "reroll_empty": 0.0, "add_chance": 0.0}
	var vanilla := _stats(common, rare, legendary)
	r.check("LootSettings: game-equivalent roll ~81% empty", vanilla.empty > 0.77 and vanilla.empty < 0.85, "%.3f empty, %.2f items" % [vanilla.empty, vanilla.mean])
	LS.overrides = {"preset": "Balanced"}
	var balanced := _stats(common, rare, legendary)
	r.check("LootSettings: Balanced ~half empty, more loot", balanced.empty > 0.44 and balanced.empty < 0.58 and balanced.mean > vanilla.mean, "%.3f empty, %.2f items" % [balanced.empty, balanced.mean])
	LS.overrides = {"preset": "Loot Overhaul"}
	var overhaul := _stats(common, rare, legendary)
	r.check("LootSettings: Loot Overhaul ~70% hold something", 1.0 - overhaul.empty > 0.63 and 1.0 - overhaul.empty < 0.76, "%.3f full" % (1.0 - overhaul.empty))
	LS.overrides = {"preset": "Mega Loot"}
	var mega := _stats(common, rare, legendary)
	r.check("LootSettings: Mega Loot far richer", mega.mean > balanced.mean * 2.0 and mega.empty < 0.3, "%.3f empty, %.2f items" % [mega.empty, mega.mean])
	r.check("LootSettings: Mega Loot shows every stash", bool(LS.value("stashes_always")) and bool(LS.value("no_empty_cans")))
	LS.overrides = {"preset": "Vanilla"}
	r.check("LootSettings: Vanilla leaves the game alone", not LS.changes_loot())

	# The real hooks: a container and floor loot roll with the preset
	var containers := []
	var floors := []
	for n in r.get_tree().current_scene.find_children("*", "", true, false):
		if n is LootContainer and n.custom.is_empty() and not n.locked and not n.furniture:
			containers.append(n)
		elif n.get_script() and str(n.get_script().resource_path).ends_with("LootSimulation.gd") or (n.has_method("SpawnItems") and "commonBucket" in n):
			floors.append(n)
	LS.overrides = {"preset": "Mega Loot"}
	if not containers.is_empty():
		var c = containers[0]
		if c.commonBucket.is_empty():
			c.ClearBuckets()
			c.FillBuckets()
		var total := 0
		for i in 40:
			c.loot.clear()
			c.GenerateLoot()
			total += c.loot.size()
		r.check("LootSettings: containers use the preset", total / 40.0 > 2.0, "%.2f items per container" % (total / 40.0))
		var gd = load("res://Resources/GameData.tres")
		gd.tutorial = false
		LS.overrides = {"preset": "Custom", "condition_min": 90, "condition_max": 95}
		c.loot.clear()
		c.CreateLoot(load("res://Items/Weapons/AKM/AKM.tres"))
		gd.tutorial = true
		r.check("LootSettings: weapon condition range", c.loot.size() == 1 and c.loot[0].condition >= 90 and c.loot[0].condition <= 95, str(c.loot[0].condition) if c.loot.size() else "none")
		c.loot.clear()
	else:
		r.check("LootSettings: found a container to roll", false)
	var made = null
	if floors.is_empty():
		# The Tutorial has no floor loot: make a spot with the game's script.
		made = Node3D.new()
		made.set_script(load("res://Scripts/LootSimulation.gd"))
		made.civilian = true
		floors.append(made)
	if not floors.is_empty():
		LS.overrides = {"preset": "Mega Loot"}
		var f = floors[0]
		if f.commonBucket.is_empty():
			f.ClearBuckets()
			f.FillBuckets()
		var total := 0
		for i in 40:
			f.loot.clear()
			f.GenerateLoot()
			total += f.loot.size()
		f.loot.clear()
		r.check("LootSettings: floor loot uses the preset", total / 40.0 > 2.0, "%.2f items per spot" % (total / 40.0))
	if made:
		made.free()
	LS.overrides = {}


func _stats(common: Array, rare: Array, legendary: Array) -> Dictionary:
	var empty := 0
	var items := 0
	for i in N:
		var got := LS.roll(common, rare, legendary)
		if got.is_empty():
			empty += 1
		items += got.size()
	return {"empty": float(empty) / N, "mean": float(items) / N}
