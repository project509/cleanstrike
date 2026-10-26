# Self-test for CleanStrike Fixes Overhaul (cs_fixes_overhaul). r is the CSTest runner.
extends RefCounted

const FO = preload("res://CSFixesOverhaul/Mod.gd")


func run(r) -> void:
	r.check("FixesOverhaul: active", FO.active())
	var gd = load("res://Resources/GameData.tres")
	var scene = r.get_tree().current_scene

	# Doors swing away from whichever side you stand on
	var door = null
	for n in scene.find_children("*", "", true, false):
		if n is Door and absf(n.openAngle.y) > 1.0 and absf(FO.door_panel_center(n).x) > 0.05:
			door = n
			break
	if door:
		var panel := FO.door_panel_center(door)
		var ok := true
		for side in [-1.0, 1.0]:
			var stand: Vector3 = door.to_global(Vector3(panel.x, 0.0, panel.z + side * 1.5))
			var s := FO.door_away_sign(door, stand)
			# Where the panel ends up when opened by that much, in the door's frame
			var opened := panel.rotated(Vector3.UP, deg_to_rad(absf(door.openAngle.y) * s))
			ok = ok and s != 0 and signf(opened.z - panel.z) == -side
		r.check("FixesOverhaul: doors swing away from you (both sides)", ok)
	else:
		r.check("FixesOverhaul: found a hinged door", false)

	var f := FO.area_flags(["Indoor", "Fire", "PRX_Workbench"])
	r.check("FixesOverhaul: overlapping areas all apply", f.indoor and f.isBurning and f.PRX_Workbench and not f.heat)
	r.check("FixesOverhaul: AI sight on a foggy night is the night's", FO.sight_distance(true, true) == 40.0 and FO.sight_distance(true, false) == 100.0 and FO.sight_distance(false, false) == 150.0)

	# Fair event odds
	var events: Array = load("res://Events/Events.tres").events
	var airdrop = events.filter(func(e): return str(e.function) == "Airdrop")[0]
	var jets = events.filter(func(e): return str(e.function) == "FighterJet")[0]
	var a := 0
	var j := 0
	for i in 20000:
		var e = FO.fair_pick([airdrop, jets], 20.0)
		if e == airdrop: a += 1
		elif e == jets: j += 1
	r.check("FixesOverhaul: event chances are the stated ones", absf(a / 20000.0 - airdrop.possibility / 100.0) < 0.012 and absf(j / 20000.0 - jets.possibility / 100.0) < 0.015, "%.3f / %.3f" % [a / 20000.0, j / 20000.0])
	var cs = Engine.get_meta("Cleanstrike")
	var hooked := false
	var s = load("res://Scripts/EventSystem.gd")
	while s:
		if s.get_script_constant_map().has("FO"):
			hooked = true
		s = s.get_base_script()
	r.check("FixesOverhaul: event fix stands aside for Event Hints", hooked != cs.is_loaded("cs_event_hints"))

	# Catalog room check
	var interface = r.get_node("/root/Map/Core/UI/Interface")
	var small := ItemData.new()
	small.size = Vector2(1, 1)
	var huge := ItemData.new()
	huge.size = Vector2(99, 99)
	r.check("FixesOverhaul: catalog room check", interface.FO_CatalogHasRoom(small) and not interface.FO_CatalogHasRoom(huge))

	# [Empty] on emptied containers
	var box = null
	for n in scene.find_children("*", "", true, false):
		if n is LootContainer and not n.locked:
			box = n
			break
	if box:
		var was_storaged: bool = box.storaged
		var was_storage: Array = box.storage.duplicate()
		box.storaged = true
		box.storage.clear()
		box.set_meta("tl_searched", true)   # you can only empty what you've searched
		box.set_meta("rtt_searched", true)
		box.UpdateTooltip()
		r.check("FixesOverhaul: emptied container says [Empty]", gd.tooltip.ends_with("[Empty]"), gd.tooltip)
		box.remove_meta("tl_searched")
		box.remove_meta("rtt_searched")
		box.storaged = was_storaged
		box.storage.assign(was_storage)

	# Floor loot: a forced table spawns each item exactly once
	var table := LootTable.new()
	for p in ["res://Items/Weapons/AKM/AKM_Magazine.tres", "res://Items/Consumables/Can_Empty/Can_Empty.tres", "res://Items/Weapons/AKM/AKM.tres"]:
		table.items.append(load(p))
	var spot := Node3D.new()
	spot.set_script(load("res://Scripts/LootSimulation.gd"))
	spot.add_child(Node3D.new())   # the placeholder the game removes
	spot.custom = table
	spot.force = true
	scene.add_child(spot)
	await r.wait(0.3)
	var spawned := spot.get_children().filter(func(c): return not c.is_queued_for_deletion() and "slotData" in c).size()
	r.check("FixesOverhaul: forced floor loot spawns each item once", spawned == 3, "%d spawned (the game: 6)" % spawned)
	spot.queue_free()

	# Unstuck: back to where you stood
	var ctrl = r.get_node("/root/Map/Core/Controller")
	if "fo_safe" in ctrl:
		var home: Vector3 = ctrl.global_position
		ctrl.fo_safe = [[ctrl.fo_clock - 6.0, home]]
		ctrl.global_position = home + Vector3(0, 30, 0)
		ctrl.FO_Unstuck()
		r.check("FixesOverhaul: unstuck goes back", ctrl.global_position.distance_to(home) < 0.1)
		ctrl.global_position = home

	# Trader: tax and tasks redrawn once progress has loaded
	var trader = null
	for n in scene.find_children("*", "", true, false):
		if n is Trader:
			trader = n
			break
	if trader:
		var t := 0.0
		while trader.traderBucket.is_empty() and t < 10.0:
			await r.wait(0.25)
			t += 0.25
		trader.Activate()
		var done: Array = trader.tasksCompleted.duplicate()
		var ui = r.get_node("/root/Map/Core/UI")
		ui.OpenTrader(trader)
		trader.tasksCompleted.append("FO test task")   # as if progress arrived late
		var want := str(done.size() + 1) + "/"
		var waited := 0.0
		while not interface.traderTasks.text.begins_with(want) and waited < 2.0:
			await r.wait(0.1)
			waited += 0.1
		r.check("FixesOverhaul: trader info redrawn after progress loads", interface.traderTasks.text.begins_with(str(done.size() + 1) + "/"), interface.traderTasks.text)
		r.close_ui(ui)
		await r.wait(0.3)
		trader.tasksCompleted.assign(done)
		r.check("FixesOverhaul: trader shadows switch", trader.FO_QuietShadows() > 0)
