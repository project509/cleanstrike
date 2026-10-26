# Headless end-to-end test for Road to Tarkov. Writes user://cleanstrike/selftest.json
extends Node

var started := false
var menu_preview_button := false
var results := []
var failures := 0

func check(name: String, ok: bool, detail := "") -> void:
	results.append({"name": name, "ok": ok, "detail": detail})
	if not ok: failures += 1
	print("[CSTest] %s %s %s" % ["PASS" if ok else "FAIL", name, detail])

func _ready() -> void:
	get_tree().create_timer(460.0, true, false, true).timeout.connect(func(): check("timeout", false); finish())
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
	var RTT = load("res://RoadToTarkov/RTT.gd")
	var cs = Engine.get_meta("Cleanstrike")
	check("mod loaded", cs.is_loaded("road_to_tarkov"))
	check("RTT active", RTT.active())
	check("main menu has Customs preview", menu_preview_button)
	var ui = get_node("/root/Map/Core/UI")
	var interface = get_node("/root/Map/Core/UI/Interface")
	check("interface extended", interface.has_method("RTT_ContextExamine"))

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
	if target == null: return finish()
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
	check("items use mod script", items[0].has_method("RTT_SetProgress"))
	check("slotData kept through swap", items[0].slotData != null and items[0].slotData.itemData != null)
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
	check("container marked searched", bool(target.get_meta("rtt_searched", false)))
	check("header restored", not ("Searching" in interface.containerName.text), interface.containerName.text)

	# Unknown items
	var unknown = null
	for i in items:
		if RTT.is_unknown(i): unknown = i; break
	check("found unknown item", unknown != null)
	if unknown:
		check("unknown mark shown", unknown.rtt_mark != null and unknown.rtt_mark.visible)
		check("abbreviation hidden", unknown.abbreviation.text == "?", unknown.abbreviation.text)
		interface.tooltip.Update(unknown)
		check("tooltip unknown", interface.tooltip.title.text == "Unknown item", interface.tooltip.title.text)
		interface.contextItem = unknown
		interface.contextGrid = interface.containerGrid
		interface.context.Update(unknown.slotData)
		var ex = interface.context.rtt_examine
		check("examine button", ex != null and ex.visible)
		check("use hidden for unknown", not interface.context.useButton.visible)
		interface.RTT_ContextExamine()
		check("examining", interface.RTT_IsExamining(unknown))
		var total: float = RTT.examine_time(unknown.slotData.itemData)
		await wait(total + 0.8)
		check("examined -> known", not RTT.is_unknown(unknown), "after %.1fs" % total)
		check("mark cleared", not unknown.rtt_mark.visible)
		interface.tooltip.Update(unknown)
		check("tooltip shows name", interface.tooltip.title.text == unknown.slotData.itemData.name, interface.tooltip.title.text)
		check("tint applied", unknown.fill.color == RTT.tint_for(unknown.slotData.itemData), str(unknown.fill.color))

	close_ui(ui)
	await wait(0.3)
	ui.OpenContainer(target)
	await wait(0.3)
	items = interface.containerGrid.get_children()
	check("no re-search after complete", not items.any(func(i): return RTT.is_hidden(i)) and not ("Searching" in interface.containerName.text), interface.containerName.text)
	close_ui(ui)
	target.UpdateTooltip()
	check("tooltip says Open after search", target.gameData.tooltip.ends_with("[Open]"), target.gameData.tooltip)
	await customs_tests(ui, interface)
	finish()

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
