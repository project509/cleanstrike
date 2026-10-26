# Headless end-to-end test for Cleanstrike's mods. Writes user://cleanstrike/selftest.json
# Each mod's own checks live in CSTest/Mods/<Mod>.gd and run only when that
# mod is loaded; the looting and Customs checks below run when theirs are.
extends Node

# mod id -> test script. A test script is a RefCounted with
#   func run(r)        checks that leave the game where it was
#   func run_last(r)   optional, may die/travel; must end back in the Tutorial
const MOD_TESTS := {
	"cs_faction_warfare": "res://CSTest/Mods/FactionWarfare.gd",
	"cs_death_hit_effects": "res://CSTest/Mods/DeathHitEffects.gd",
	"cs_weather_seasons": "res://CSTest/Mods/WeatherSeasons.gd",
	"cs_reticles": "res://CSTest/Mods/Reticles.gd",
	"cs_custom_fonts": "res://CSTest/Mods/CustomFonts.gd",
	"cs_tactical_watch": "res://CSTest/Mods/TacticalWatch.gd",
	"cs_hud": "res://CSTest/Mods/HUD.gd",
	"cs_better_inventory": "res://CSTest/Mods/BetterInventory.gd",
	"cs_better_map": "res://CSTest/Mods/BetterMap.gd",
	"cs_everything_lootable": "res://CSTest/Mods/EverythingLootable.gd",
	"cs_injuries_rework": "res://CSTest/Mods/InjuriesRework.gd",
	"cs_multi_use_items": "res://CSTest/Mods/MultiUseItems.gd",
	"cs_clothes_to_rags": "res://CSTest/Mods/ClothesToRags.gd",
	"cs_cash_money": "res://CSTest/Mods/CashMoney.gd",
	"cs_loot_highlight": "res://CSTest/Mods/LootHighlight.gd",
	"cs_item_clarity": "res://CSTest/Mods/ItemClarity.gd",
	"cs_sound_indicators": "res://CSTest/Mods/SoundIndicators.gd",
	"cs_heli_go_boom": "res://CSTest/Mods/HeliGoBoom.gd",
	"cs_airdrops": "res://CSTest/Mods/Airdrops.gd",
	"cs_weapon_position": "res://CSTest/Mods/WeaponPosition.gd",
	"cs_better_lean": "res://CSTest/Mods/BetterLean.gd",
	"cs_burst_fire": "res://CSTest/Mods/BurstFire.gd",
	"cs_scope_sensitivity": "res://CSTest/Mods/ScopeSensitivity.gd",
	"cs_save_anywhere": "res://CSTest/Mods/SaveAnywhere.gd",
	"cs_kill_counter": "res://CSTest/Mods/KillCounter.gd",
	"cs_infinite_bedding": "res://CSTest/Mods/InfiniteBedding.gd",
	"cs_immortal_cat": "res://CSTest/Mods/ImmortalCat.gd",
	"cs_gear_spawns": "res://CSTest/Mods/GearSpawns.gd",
	"cs_medical_durability": "res://CSTest/Mods/MedicalDurability.gd",
	"cs_hold_breath": "res://CSTest/Mods/HoldBreath.gd",
	"cs_focus_zoom": "res://CSTest/Mods/FocusZoom.gd",
	"cs_event_hints": "res://CSTest/Mods/EventHints.gd",
	"cs_better_enemy_loot": "res://CSTest/Mods/BetterEnemyLoot.gd",
	"cs_loot_settings": "res://CSTest/Mods/LootSettings.gd",
	"cs_better_traders": "res://CSTest/Mods/BetterTraders.gd",
	"cs_fixes_overhaul": "res://CSTest/Mods/FixesOverhaul.gd",
	"cs_no_permadeath": "res://CSTest/Mods/NoPermadeath.gd",
}

var started := false
var menu_preview_button := false
var results := []
var failures := 0

func check(name: String, ok: bool, detail := "") -> void:
	results.append({"name": name, "ok": ok, "detail": detail})
	if not ok: failures += 1
	print("[CSTest] %s %s %s" % ["PASS" if ok else "FAIL", name, detail])

func _ready() -> void:
	get_tree().create_timer(900.0, true, false, true).timeout.connect(func(): check("timeout", false); finish())
	run.call_deferred()

func wait(s: float) -> void:
	await get_tree().create_timer(s, true, true, true).timeout

func find_containers(n: Node, out: Array) -> void:
	if n is LootContainer: out.append(n)
	for c in n.get_children(): find_containers(c, out)

func run() -> void:
	while get_tree().current_scene == null or get_node_or_null("/root/Map/Core/UI/Interface") == null:
		await wait(0.5)
	await wait(4.0)
	var cs = Engine.get_meta("Cleanstrike")
	# Every mod in this launch must have loaded (a rolled-back mod would
	# otherwise just skip its tests).
	for m in cs.mods:
		if m.get("enabled", true) and str(m.get("id", "")) != "cs_selftest" and not str(m.get("id", "")).begins_with("cs_testclash"):
			check("%s loaded" % m.id, m.get("status", "") == "loaded", str(m.get("reason", m.get("status", ""))))
	# The loader's safety net: of two mods that can't run together, the
	# first loads and the second is skipped with the reason.
	var clash_a = cs.mods.filter(func(m): return m.get("id", "") == "cs_testclash_a")
	var clash_b = cs.mods.filter(func(m): return m.get("id", "") == "cs_testclash_b")
	if clash_a.size() == 1 and clash_b.size() == 1:
		check("loader: first of two clashing mods loads", clash_a[0].status == "loaded")
		check("loader: the clashing one is skipped, with the reason", clash_b[0].status == "incompatible" and "Test mods that must never run together" in str(clash_b[0].reason), str(clash_b[0].reason))
	var mod_tests := []
	for id in MOD_TESTS:
		if cs.is_loaded(id):
			# A test that fails to compile must fail the run, not vanish.
			var script = load(MOD_TESTS[id])
			var ok: bool = script != null and script.can_instantiate()
			check("test script compiles: " + MOD_TESTS[id].get_file(), ok)
			if ok:
				mod_tests.append(script.new())
	for t in mod_tests:
		await t.run(self)
	for t in mod_tests:
		if t.has_method("run_last"):
			await t.run_last(self)
	if cs.is_loaded("tarkov_looting") or cs.is_loaded("road_to_tarkov"):
		# A fresh Tutorial, so nothing a mod test did (items, flags) carries over.
		if not mod_tests.is_empty():
			check("fresh Tutorial for the looting checks", await reload_tutorial())
		await looting_tests(cs)
	finish()


func looting_tests(cs) -> void:
	# Looting comes from Tarkov Looting when it is loaded, else Road to Tarkov.
	var standalone: bool = cs.is_loaded("tarkov_looting")
	var RTT = load("res://TarkovLooting/TL.gd") if standalone else load("res://RoadToTarkov/RTT.gd")
	var P := "TL_" if standalone else "RTT_"
	var pl := "tl_" if standalone else "rtt_"
	print("[CSTest] looting provided by ", "tarkov_looting" if standalone else "road_to_tarkov")
	check("looting mod loaded", cs.is_loaded("tarkov_looting" if standalone else "road_to_tarkov"))
	check("looting active", RTT.active())
	if standalone and cs.is_loaded("road_to_tarkov"):
		var R = load("res://RoadToTarkov/RTT.gd")
		check("Road to Tarkov steps aside for Tarkov Looting", R.active() and not R.looting())
	if cs.is_loaded("road_to_tarkov"):
		check("main menu has Customs preview", menu_preview_button)
	var ui = get_node("/root/Map/Core/UI")
	var interface = get_node("/root/Map/Core/UI/Interface")
	check("interface extended", interface.has_method(P + "ContextExamine"))

	check("type check: Node3D is not LootContainer", not (Node3D.new() is LootContainer))
	check("type check: Panel is not Item", not (Panel.new() is Item))
	check("type check: RigidBody3D is not Pickup", not (RigidBody3D.new() is Pickup))
	var containers := []
	find_containers(get_tree().current_scene, containers)
	var target = null
	for c in containers:
		if not c.locked and not c.furniture and c.loot.size() >= 2:
			target = c; break
	if target == null:
		for c in containers:
			if not c.locked and not c.furniture:
				target = c; break
	check("found container", target != null, "%d containers" % containers.size())
	if target == null: return
	if target.loot.size() < 2:
		for i in 3: target.CreateLoot(load("res://Loot/LT_Master.tres").items.pick_random())
	var n_loot: int = target.loot.size()

	target.UpdateTooltip()
	check("tooltip says Search", target.gameData.tooltip.ends_with("[Search]"), target.gameData.tooltip)

	ui.OpenContainer(target)
	await wait(0.2)
	var items: Array = interface.containerGrid.get_children()
	check("items placed", items.size() > 0, "%d of %d" % [items.size(), n_loot])
	var hidden: Array = items.filter(func(i): return RTT.is_hidden(i))
	check("all hidden at start", hidden.size() == items.size(), "%d hidden" % hidden.size())
	check("header searching", "Searching" in interface.containerName.text, interface.containerName.text)
	check("items use mod script", items[0].has_method(P + "SetProgress"))
	check("slotData kept through swap", items[0].slotData != null and items[0].slotData.itemData != null)
	if standalone:
		var ghosts: Array = []
		for k in 20:   # poll: between a reveal and the next pick there are frames with no ghost
			await wait(0.05)
			ghosts = items.filter(func(i): return i.tl_preview)
			if ghosts.size() == 1 and k >= 10: break
		var g = ghosts[0] if ghosts.size() == 1 else null
		check("one grey preview while searching", g != null and RTT.is_hidden(g) and g.modulate.a > 0.9, "%d previews" % ghosts.size())
		if g:
			check("preview is a ghost silhouette", g.sprite.material == RTT.silhouette(RTT.SILHOUETTE_PREVIEW) and not g.details.visible)
			check("preview cannot be grabbed", interface.GetHoverItem() != g)
		check("search sounds load", RTT.sound("rummage") != null and RTT.sound("found") != null)
		check("rummage plays while searching", interface.tl_rummage != null and interface.tl_rummage.playing)
		await wait(0.9)
	else:
		await wait(1.6)
	var revealed: int = items.filter(func(i): return not RTT.is_hidden(i)).size()
	check("reveals over time", revealed >= 1 and revealed < items.size() or items.size() == 1, "%d revealed after 1.6s" % revealed)

	# Close mid-search, reopen: progress must persist.
	close_ui(ui)
	await wait(0.3)
	ui.OpenContainer(target)
	await wait(0.1)
	items = interface.containerGrid.get_children()
	var revealed2: int = items.filter(func(i): return not RTT.is_hidden(i)).size()
	check("progress persists after reopen", revealed2 >= revealed, "%d -> %d" % [revealed, revealed2])

	var t := 0.0
	while items.any(func(i): return RTT.is_hidden(i)) and t < 60.0:
		await wait(0.5); t += 0.5
	check("search completes", not items.any(func(i): return RTT.is_hidden(i)), "%.1fs" % t)
	await wait(0.6)
	check("container marked searched", bool(target.get_meta(pl + "searched", false)))
	check("header restored", not ("Searching" in interface.containerName.text), interface.containerName.text)

	# Unknown items
	var unknown = null
	for i in items:
		if RTT.is_unknown(i): unknown = i; break
	check("found unknown item", unknown != null)
	if unknown:
		var mark = unknown.get(pl + "mark")
		check("unknown mark shown", mark != null and mark.visible)
		check("abbreviation hidden", unknown.abbreviation.text == "?", unknown.abbreviation.text)
		if standalone:
			check("unknown icon obscured", unknown.sprite.material == RTT.silhouette(RTT.SILHOUETTE_UNKNOWN))
			check("unknown cell untinted", unknown.fill.color == RTT.DEFAULT_TINT, str(unknown.fill.color))
		interface.tooltip.Update(unknown)
		check("tooltip unknown", interface.tooltip.title.text == "Unknown item", interface.tooltip.title.text)
		if standalone:
			check("tooltip says not examined", "Not examined" in interface.tooltip.type.text, interface.tooltip.type.text)
		interface.contextItem = unknown
		interface.contextGrid = interface.containerGrid
		interface.context.Update(unknown.slotData)
		var ex = interface.context.get(pl + "examine")
		check("examine button", ex != null and ex.visible)
		check("use hidden for unknown", not interface.context.useButton.visible)
		if standalone:
			# Middle mouse over the item, as a player would.
			HideCtx(interface)
			interface.hoverItem = unknown
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_MIDDLE
			mb.pressed = true
			interface._input(mb)
		else:
			interface.call(P + "ContextExamine")
		check("examining" + (" (middle-click)" if standalone else ""), interface.call(P + "IsExamining", unknown))
		if standalone:
			await wait(0.3)
			check("examine queue shown", interface.tl_queue_label != null and interface.tl_queue_label.visible and "Examining" in interface.tl_queue_label.text, interface.tl_queue_label.text if interface.tl_queue_label else "")
			check("examine progresses", interface.TL_ExamineProgress(unknown) > 0.0)
		var total: float = RTT.examine_time(unknown.slotData.itemData)
		await wait(total + 0.8)
		check("examined -> known", not RTT.is_unknown(unknown), "after %.1fs" % total)
		check("mark cleared", not unknown.get(pl + "mark").visible)
		if standalone:
			var m = unknown.sprite.material
			check("icon revealed", m != RTT.silhouette(RTT.SILHOUETTE_UNKNOWN) and m != RTT.silhouette(RTT.SILHOUETTE_PREVIEW), str(m))
		interface.tooltip.Update(unknown)
		check("tooltip shows name", interface.tooltip.title.text == unknown.slotData.itemData.name, interface.tooltip.title.text)
		check("tint applied", unknown.fill.color == RTT.tint_for(unknown.slotData.itemData), str(unknown.fill.color))

	if standalone:
		# Weapons and magazines work while unknown; other types don't.
		var mag := SlotData.new()
		mag.itemData = load("res://Items/Weapons/AKM/AKM_Magazine.tres")
		RTT._known.erase(mag.itemData.file)
		check("rummage stops when search ends", not interface.tl_rummage.playing)
		var gd = load("res://Resources/GameData.tres")
		var f0: float = RTT.character_factor()
		gd.fracture = true
		check("fracture slows searching", RTT.character_factor() > f0 * 1.3, "%.2f" % RTT.character_factor())
		gd.fracture = false
		check("bodies show worn gear", RTT.is_worn_gear(load("res://Items/Weapons/AKM/AKM.tres")) and not RTT.is_worn_gear(load("res://Items/Weapons/AKM/AKM_Magazine.tres")))
		var bordered := 0
		for it in load("res://Loot/LT_Master.tres").items:
			if RTT.value_color(it).a > 0.0: bordered += 1
		check("value borders on some loot", bordered > 0, "%d bordered" % bordered)
		check("unknown magazine is usable", RTT.is_unknown(mag) and not RTT.is_restricted(mag), mag.itemData.subtype)
		var gun := SlotData.new()
		gun.itemData = load("res://Items/Weapons/AKM/AKM.tres")
		RTT._known.erase(gun.itemData.file)
		check("unknown weapon is usable", RTT.is_unknown(gun) and not RTT.is_restricted(gun), gun.itemData.type)
		var other = items.filter(func(i): return not (str(i.slotData.itemData.type) in RTT.USABLE_UNKNOWN or str(i.slotData.itemData.subtype) in RTT.USABLE_UNKNOWN))
		if other.size() > 0:
			var od: SlotData = other[0].slotData
			RTT._known.erase(od.itemData.file)
			check("unknown non-weapon is restricted", RTT.is_restricted(od), od.itemData.type)

	close_ui(ui)
	await wait(0.3)
	ui.OpenContainer(target)
	await wait(0.3)
	items = interface.containerGrid.get_children()
	check("no re-search after complete", not items.any(func(i): return RTT.is_hidden(i)) and not ("Searching" in interface.containerName.text), interface.containerName.text)
	close_ui(ui)
	target.UpdateTooltip()
	check("tooltip says Open after search", target.gameData.tooltip.ends_with("[Open]"), target.gameData.tooltip)
	if cs.is_loaded("road_to_tarkov"):
		await customs_tests(ui, interface)

# Back to a fresh Tutorial (after a test that died or travelled).
func reload_tutorial() -> bool:
	Loader.LoadScene("Tutorial")
	var ok: bool = await wait_for_map("Tutorial", 60.0)
	await wait(4.0)   # same settling time as the first load (the Tutorial's own start-up)
	return ok

func map_name() -> String:
	var m = get_node_or_null("/root/Map")
	return m.mapName if m and "mapName" in m else ""

func wait_for_map(name: String, limit: float) -> bool:
	var t := 0.0
	var gd = load("res://Resources/GameData.tres")
	while t < limit:
		if map_name() == name and not gd.isCaching and not gd.isTransitioning and get_node_or_null("/root/Map/Core/Controller") != null:
			await wait(1.0)
			return true
		await wait(0.5); t += 0.5
	return false

func spawn_distance(transition_name: String) -> float:
	for t in get_tree().get_nodes_in_group("Transition"):
		if t.owner and t.owner.name == transition_name and t.owner.spawn:
			return get_node("/root/Map/Core/Controller").global_position.distance_to(t.owner.spawn.global_position)
	return -1.0

func customs_tests(ui, interface) -> void:
	var gd = load("res://Resources/GameData.tres")
	var tr = load("res://Resources/Transition.tscn").instantiate()
	tr.nextMap = "School"; tr.currentMap = "Village"; tr.nextZone = "Area 05"; tr.time = 1.0
	get_tree().current_scene.add_child(tr)
	check("transition extended", tr.has_method("RTT_OffersCustoms") and tr.RTT_OffersCustoms())
	var hud = get_node("/root/Map/Core/UI/HUD")
	hud.Transition(tr)
	check("HUD prompt mentions Customs", hud.destination.text == "School / Customs", hud.destination.text)

	gd.isTransitioning = true
	tr.Interact()
	await wait(0.3)
	var picker = ui.get_node_or_null("RTT_DestinationPicker")
	check("picker opens", picker != null)
	if picker == null: return
	check("picker has 2 cards", picker._cards.size() == 2)
	var thumbs := 0
	for c in picker._cards:
		for n in c.find_children("*", "TextureRect", true, false):
			if n.texture and n.texture.get_size().x >= 600: thumbs += 1
	check("thumbnails loaded", thumbs == 2, "%d" % thumbs)
	check("game frozen behind picker", gd.freeze)
	picker._cancel()
	await wait(0.3)
	check("cancel closes picker", ui.get_node_or_null("RTT_DestinationPicker") == null and not gd.freeze and not gd.isTransitioning)

	gd.isTransitioning = true
	tr.Interact()
	await wait(0.3)
	ui.get_node("RTT_DestinationPicker").choose("Customs")
	check("loads Customs", await wait_for_map("Customs", 90.0), map_name())
	check("arrived at the Village road", spawn_distance("Transition_Village") >= 0.0 and spawn_distance("Transition_Village") < 3.0, "%.1f m" % spawn_distance("Transition_Village"))
	var exits := get_tree().get_nodes_in_group("Transition").size()
	check("Customs has its exits", exits >= 13, "%d" % exits)
	var to_village := 0
	for t in get_tree().get_nodes_in_group("Transition"):
		if t.owner and t.owner.nextMap == "Village": to_village += 1
	check("exits keep their destinations", to_village >= 5, "%d to Village" % to_village)
	var player: Vector3 = get_node("/root/Map/Core/Controller").global_position
	check("player above water line", player.y > -1.5, "y=%.1f" % player.y)
	# AI on Customs
	var ai = null
	for n in get_tree().current_scene.find_children("AI", "Node3D", true, false):
		if n.get_script() and n.get_script().resource_path.ends_with("AISpawner.gd"):
			ai = n
	check("Customs has AI spawner", ai != null and ai.get("active") == true)
	var wpn := get_tree().get_nodes_in_group("AI_WP").size()
	var spn := get_tree().get_nodes_in_group("AI_SP").size()
	var ppn := get_tree().get_nodes_in_group("AI_PP").size()
	check("AI waypoints/spawns/patrols", wpn >= 100 and spn >= 10 and ppn >= 20, "WP %d SP %d PP %d" % [wpn, spn, ppn])
	var nav_map: RID = get_node("/root/Map").get_world_3d().get_navigation_map()
	await wait(1.0)
	# Customs' own spawns (under AI/Points), the two farthest apart.
	var own: Array = []
	for sp in get_tree().get_nodes_in_group("AI_SP"):
		if sp.get_parent().name == "Points": own.append(sp.global_position)
	var a3: Vector3 = own[0]
	var b3: Vector3 = own[0]
	for p1 in own:
		for p2 in own:
			if p1.distance_to(p2) > a3.distance_to(b3):
				a3 = p1; b3 = p2
	var qa := NavigationPathQueryParameters3D.new()
	qa.map = nav_map; qa.start_position = a3; qa.target_position = b3
	qa.set("path_search_max_polygons", 30000)
	var qa_r := NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(qa, qa_r)
	var path := qa_r.get_path()
	var plen := 0.0
	for i in range(1, path.size()): plen += path[i].distance_to(path[i - 1])
	# Reachability map of Customs' waypoints from the first spawn (for debugging).
	var rf := FileAccess.open("user://cleanstrike/nav_reach.txt", FileAccess.WRITE)
	var reach := 0
	var wps_all := get_tree().get_nodes_in_group("AI_WP")
	for wp in wps_all:
		var pp: Vector3 = wp.global_position
		var qpp := NavigationPathQueryParameters3D.new()
		qpp.map = nav_map; qpp.start_position = a3; qpp.target_position = pp
		qpp.set("path_search_max_polygons", 30000)
		var qrr := NavigationPathQueryResult3D.new()
		NavigationServer3D.query_path(qpp, qrr)
		var pth := qrr.get_path()
		var ok := pth.size() > 0 and pth[-1].distance_to(pp) < 3.0
		if ok: reach += 1
		rf.store_line("%f %f %d" % [pp.x, pp.z, 1 if ok else 0])
	rf.store_line("S %f %f" % [a3.x, a3.z])
	rf.close()
	check("waypoints reachable", reach >= wps_all.size() * 0.85, "%d/%d" % [reach, wps_all.size()])
	check("navmesh path across Customs", path.size() > 2 and path[-1].distance_to(b3) < 3.0, "%d pts, %.0f m (direct %.0f m)" % [path.size(), plen, a3.distance_to(b3)])
	await wait(6.0)
	var pooled := 0
	if ai:
		for n in ["E_Pool", "Enemies"]:
			var nd = ai.get_node_or_null(n)
			if nd: pooled += nd.get_child_count()
	var agents := get_tree().current_scene.find_children("*", "NavigationAgent3D", true, false)
	var budget_ok := agents.size() > 0
	for ag in agents:
		if int(ag.get("path_search_max_polygons")) < 30000: budget_ok = false
	check("scav path budget raised", budget_ok, "%d agents" % agents.size())
	check("scav pool created", pooled >= 5, "%d agents" % pooled)
	var cui = get_node("/root/Map/Core/UI")
	cui.ToggleInterface()
	await wait(0.4)
	var world: TextureRect = get_node("/root/Map/Core/UI/Interface").mapScroll.get_child(0)
	check("map tool shows Customs map", world.texture != null and world.texture.get_size() == Vector2(3840, 2160) and world.get_node_or_null("Customs") != null, str(world.texture.get_size() if world.texture else "none"))
	cui.ToggleInterface()
	await wait(0.3)

	var back = null
	for t in get_tree().get_nodes_in_group("Transition"):
		if t.owner.name == "Transition_Village": back = t.owner
	gd.isTransitioning = true
	back.Interact()
	check("returns to Village", await wait_for_map("Village", 120.0), map_name())
	check("arrived on the School road", spawn_distance("Transition_School") >= 0.0 and spawn_distance("Transition_School") < 3.0, "%.1f m" % spawn_distance("Transition_School"))
	var vui = get_node("/root/Map/Core/UI")
	vui.ToggleInterface()
	await wait(0.4)
	var vworld: TextureRect = get_node("/root/Map/Core/UI/Interface").mapScroll.get_child(0)
	check("world map has Customs marker", vworld.get_node_or_null("Customs") != null)
	vui.ToggleInterface()
	await wait(0.5)
	# Customs preview must never touch the player's saves.
	var save_files := ["user://Character.tres", "user://World.tres"]
	var before := {}
	for f in save_files:
		before[f] = FileAccess.get_modified_time(f) if FileAccess.file_exists(f) else 0
	Loader.LoadScene("CustomsPreview")
	check("preview loads Customs", await wait_for_map("Customs", 120.0), map_name())
	check("preview is save-free (tutorial mode)", gd.tutorial == true)
	var sp = get_tree().current_scene.find_child("Spawn_Preview", true, false)
	var pc: Vector3 = get_node("/root/Map/Core/Controller").global_position
	check("preview starts on the main road", sp != null and Vector2(pc.x, pc.z).distance_to(Vector2(sp.global_position.x, sp.global_position.z)) < 2.0, str(pc))
	var exit_node = null
	for t in get_tree().get_nodes_in_group("Transition"):
		if t.owner.name == "Transition_Village": exit_node = t.owner
	gd.isTransitioning = true
	exit_node.Interact()
	var tm := 0.0
	while tm < 60.0 and (get_tree().current_scene == null or get_tree().current_scene.scene_file_path != "res://Scenes/Menu.tscn"):
		await wait(0.5); tm += 0.5
	check("preview exit returns to menu", get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://Scenes/Menu.tscn", str(get_tree().current_scene.scene_file_path if get_tree().current_scene else ""))
	var unchanged := true
	for f in save_files:
		var now = FileAccess.get_modified_time(f) if FileAccess.file_exists(f) else 0
		if now != before[f]: unchanged = false
	check("preview left saves untouched", unchanged)

func close_ui(ui) -> void:
	ui.gameData.interface = true
	ui.ToggleInterface()

func finish() -> void:
	var f = FileAccess.open("user://cleanstrike/selftest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"failures": failures, "results": results}, "  "))
	f.close()
	get_tree().quit(1 if failures else 0)


func HideCtx(interface) -> void:
	if interface.context.visible:
		interface.HideContext()
	interface.Reset()
