# Self-test for Better Traders (cs_better_traders). r is the CSTest runner.
# Uses the Tutorial's Generalist. The Tutorial never saves trader data.
extends RefCounted

const M = preload("res://CSBetterTraders/Mod.gd")


func run(r) -> void:
	r.check("BetterTraders: active", M.active())
	# Whole-number settings arrive from the settings file as floats
	var cs = Engine.get_meta("Cleanstrike")
	var cached = cs._settings_cache.get(M.MOD_ID)
	cs._settings_cache[M.MOD_ID] = {"goods_count": 60.0}
	var gc = M.setting("goods_count")
	r.check("BetterTraders: whole-number setting from the app", typeof(gc) == TYPE_INT and gc == 60, str(gc))
	if cached == null:
		cs._settings_cache.erase(M.MOD_ID)
	else:
		cs._settings_cache[M.MOD_ID] = cached
	var trader = null
	for n in r.get_tree().current_scene.find_children("*", "", true, false):
		if n is Trader:
			trader = n
			break
	r.check("BetterTraders: found a trader", trader != null)
	if trader == null:
		return
	r.check("BetterTraders: trader uses the mod", trader.has_method("BT_SetTab"))
	if not trader.has_method("BT_SetTab"):
		return
	trader.Activate()
	# The game fills a trader's range 0-4 s after the map loads.
	var t := 0.0
	while trader.traderBucket.is_empty() and t < 10.0:
		await r.wait(0.25)
		t += 0.25
	var ui = r.get_node("/root/Map/Core/UI")
	var interface = r.get_node("/root/Map/Core/UI/Interface")
	var had: Array = interface.inventoryGrid.get_children()
	M.overrides["rep"] = 0.0
	trader.CreateSupply()

	# Goods and furniture are separate lists
	r.check("BetterTraders: goods restock count", _nc(trader.bt_goods).size() == 40, str(_nc(trader.bt_goods).size()))
	r.check("BetterTraders: no furniture among goods", not trader.bt_goods.any(func(s): return M.is_furniture(s.itemData)))
	r.check("BetterTraders: furniture list is furniture", trader.bt_furniture.all(func(s): return M.is_furniture(s.itemData)), "%d furniture" % trader.bt_furniture.size())

	ui.OpenTrader(trader)
	await r.wait(0.6)
	r.check("BetterTraders: Stock and Dailies buttons", interface.bt_stock_button.visible and interface.bt_dailies_button.visible)
	r.check("BetterTraders: Goods/Furniture tabs shown", interface.bt_goods_tab.visible and interface.bt_furniture_tab.visible)
	r.check("BetterTraders: reputation line", interface.bt_rep_line.visible and interface.bt_rep_line.get_node("Value").text == "Unknown (0)", interface.bt_rep_line.get_node("Value").text)
	var items: Array = interface.supplyGrid.get_children()
	r.check("BetterTraders: Goods tab shows no furniture", items.size() > 0 and not items.any(func(i): return M.is_furniture(i.slotData.itemData)), "%d items" % items.size())
	if cs.is_loaded("tarkov_looting"):
		var TL = load("res://TarkovLooting/TL.gd")
		r.check("BetterTraders: trader items are known (Tarkov Looting)", not items.any(func(i): return TL.is_unknown(i)))

	if not trader.bt_furniture.is_empty():
		interface.BT_SetSupplyTab("furniture")
		await r.wait(0.3)
		items = _nc(interface.supplyGrid.get_children())
		r.check("BetterTraders: Furniture tab shows furniture", items.size() > 0 and items.all(func(i): return M.is_furniture(i.slotData.itemData)), "%d items" % items.size())
		interface.BT_SetSupplyTab("goods")
		await r.wait(0.2)

	# Stock by reputation
	interface.BT_ShowStock()
	await r.wait(0.3)
	items = _nc(interface.supplyGrid.get_children())
	r.check("BetterTraders: stock at Unknown = 3 items, no key", items.size() == 3 and not items.any(func(i): return i.slotData.itemData.type == "Key"), "%d items" % items.size())
	r.check("BetterTraders: header says Stock", interface.supplyUI.get_node("Header/Label").text == "Stock")
	M.overrides["rep"] = 50.0
	trader.CreateSupply()
	interface.Resupply()
	await r.wait(0.3)
	items = _nc(interface.supplyGrid.get_children())
	var key = null
	for i in items:
		if i.slotData.itemData.resource_path == M.KEYS["Generalist"]:
			key = i
	r.check("BetterTraders: Reliable stock = 12 items + Cellar Key", items.size() == 13 and key != null, "%d items" % items.size())
	if key:
		key.State("Selected")
		interface.CalculateDeal()
		r.check("BetterTraders: key costs 3000", interface.requestValue.text == "3000", interface.requestValue.text)
		interface.ResetTrading()

	# Restock hotkey and cooldown
	interface.supplyButton.pressed.emit()
	interface._on_supply_pressed()
	await r.wait(0.2)
	var before = trader.bt_goods
	interface.BT_Refresh()
	await r.wait(0.3)
	r.check("BetterTraders: restock replaces the goods", trader.bt_goods != before and interface.supplyGrid.get_child_count() > 0)
	M.overrides["refresh_cooldown"] = 5
	r.check("BetterTraders: restock cooldown", trader.BT_Refresh() > 0.0)
	M.overrides.erase("refresh_cooldown")

	# Dailies at Reliable: 4, the last a kill contract
	var tasks_before: int = trader.tasksCompleted.size()
	interface.BT_ShowDailies()
	await r.wait(0.3)
	var rows: Array = interface.taskList.get_children().filter(func(x): return not x.is_queued_for_deletion())
	r.check("BetterTraders: 4 dailies at Reliable", rows.size() == 4, str(rows.size()))
	r.check("BetterTraders: header says Dailies", interface.tasksUI.get_node("Header/Label").text == "Dailies")
	var kill_row = null
	var deliver_row = null
	for row in rows:
		if row.taskData.has_meta("bt_kill"):
			kill_row = row
		elif deliver_row == null:
			deliver_row = row
	r.check("BetterTraders: a kill contract", kill_row != null)
	# Completing a daily redraws the list (rows are freed): keep the contract.
	var kill_meta: Dictionary = kill_row.taskData.get_meta("bt_kill") if kill_row else {}
	if deliver_row:
		var td: TaskData = deliver_row.taskData
		for item in td.deliver:
			interface.Create(M.make_slot(item), interface.inventoryGrid, false)
		await r.wait(0.2)
		deliver_row._on_input_toggled(true)
		for child in interface.inventoryGrid.get_children():
			if child.slotData.itemData == td.deliver[0] and not child.selected:
				interface.hoverItem = child
				interface.InputSelection()
		deliver_row.CanComplete()
		r.check("BetterTraders: delivery can be completed", not deliver_row.completeButton.disabled, td.description)
		var reward_name: String = td.receive[0].name
		var rep_before: float = float(M.data().rep.get("Generalist", 0.0))
		deliver_row._on_complete_pressed()
		await r.wait(0.3)
		var got: bool = interface.inventoryGrid.get_children().any(func(c): return c.slotData.itemData.name == reward_name)
		r.check("BetterTraders: daily reward received", got, reward_name)
		r.check("BetterTraders: daily marked done", M.daily_done(trader, td))
		r.check("BetterTraders: daily raises reputation", float(M.data().rep.get("Generalist", 0.0)) > rep_before)
		r.check("BetterTraders: real task list untouched", trader.tasksCompleted.size() == tasks_before)
	if not kill_meta.is_empty():
		var k: Dictionary = kill_meta
		interface.BT_FillDailies()
		await r.wait(0.2)
		var waiting = interface.taskList.get_children().filter(func(x): return not x.is_queued_for_deletion() and x.taskData.has_meta("bt_kill"))
		r.check("BetterTraders: kill contract locked before kills", waiting.size() == 1 and waiting[0].completeButton.disabled)
		for i in int(k["count"]):
			M.record_kill(str(k["faction"]))
		interface.BT_FillDailies()
		await r.wait(0.2)
		var fresh = interface.taskList.get_children().filter(func(x): return not x.is_queued_for_deletion() and x.taskData.has_meta("bt_kill"))
		r.check("BetterTraders: kill contract completable after kills", fresh.size() == 1 and not fresh[0].completeButton.disabled)

	# Repairs: pretend this is the Gunsmith
	interface.supplyButton.button_pressed = true
	interface._on_supply_pressed()
	var real_name: String = trader.traderData.name
	trader.traderData.name = "Gunsmith"
	var gun := M.make_slot(load("res://Items/Weapons/AKM/AKM.tres"))
	gun.condition = 50.0
	interface.Create(gun, interface.inventoryGrid, false)
	await r.wait(0.2)
	interface._bt_refresh_panel()
	r.check("BetterTraders: Repair button at the Gunsmith", interface.bt_repair_button.visible)
	var gun_item = null
	for c in interface.inventoryGrid.get_children():
		if c.slotData.itemData.file == "AKM" and float(c.slotData.condition) == 50.0:
			gun_item = c
	if gun_item:
		interface.bt_repair_mode = true
		interface.hoverItem = gun_item
		interface.TradeSelection()
		var cost := int(round(M.repair_cost(trader, gun_item.slotData)))
		r.check("BetterTraders: repair priced", interface.requestValue.text == str(cost) and cost > 0, "%s vs %d" % [interface.requestValue.text, cost])
		interface.bt_repair_mode = false
		var pay := M.make_slot(load("res://Items/Weapons/AKM/AKM.tres"))
		interface.Create(pay, interface.inventoryGrid, false)
		await r.wait(0.2)
		for c in interface.inventoryGrid.get_children():
			if c != gun_item and c.slotData.itemData.file == "AKM" and not c.get_meta("bt_repair", false):
				c.State("Selected")
				break
		interface.CalculateDeal()
		var can_pay: bool = not interface.acceptButton.disabled
		if can_pay:
			interface.CompleteDeal()
			await r.wait(0.2)
		r.check("BetterTraders: repaired by a deal", can_pay and is_instance_valid(gun_item) and float(gun_item.slotData.condition) == 100.0)
	trader.traderData.name = real_name
	M.overrides.clear()
	r.close_ui(ui)
	await r.wait(0.3)
	# Leave the inventory as it was.
	for c in interface.inventoryGrid.get_children():
		if not (c in had):
			interface.inventoryGrid.Pick(c)
			c.queue_free()


# Without Cash Money's cash stacks (they sit outside the reputation stock).
func _nc(a: Array) -> Array:
	return a.filter(func(x): return str((x.slotData if x is Item else x).itemData.file) != "CS_Euro")
