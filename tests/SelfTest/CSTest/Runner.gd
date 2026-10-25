# Headless end-to-end test for Road to Tarkov. Writes user://cleanstrike/selftest.json
extends Node

var started := false
var results := []
var failures := 0

func check(name: String, ok: bool, detail := "") -> void:
	results.append({"name": name, "ok": ok, "detail": detail})
	if not ok: failures += 1
	print("[CSTest] %s %s %s" % ["PASS" if ok else "FAIL", name, detail])

func _ready() -> void:
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func(): check("timeout", false); finish())
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
	finish()

func close_ui(ui) -> void:
	ui.gameData.interface = true
	ui.ToggleInterface()

func finish() -> void:
	var f = FileAccess.open("user://cleanstrike/selftest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"failures": failures, "results": results}, "  "))
	f.close()
	get_tree().quit(1 if failures else 0)
