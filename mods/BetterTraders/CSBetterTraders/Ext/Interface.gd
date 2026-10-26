# Better Traders: the trader screen.
#  - Trader panel: Supply | Stock | Tasks | Dailies, and a reputation line.
#  - Supply has Goods / Furniture tabs (each generated separately).
#  - Stock: items unlocked by your reputation with this trader, plus their key.
#  - Dailies: deliveries and kill contracts, refreshed every in-game day.
#  - Repair (Gunsmith: weapons, Doctor: armor and helmets): toggle Repair in
#    the deal panel, click damaged items, pay like any other deal.
#  - Refresh hotkey (default F1) restocks the trader.
extends "res://Scripts/Interface.gd"

const M = preload("res://CSBetterTraders/Mod.gd")
const DailyRow = preload("res://CSBetterTraders/Daily.gd")
const Hotkeys = preload("res://CSBetterTraders/Hotkeys.gd")

var bt_ready := false
var bt_stock_button: Button
var bt_dailies_button: Button
var bt_goods_tab: Button
var bt_furniture_tab: Button
var bt_repair_button: Button
var bt_rep_line: Label
var bt_view := "supply"          # supply | stock | tasks | dailies
var bt_supply_tab := "goods"     # goods | furniture
var bt_repair_mode := false


# ---------------------------------------------------------------- open

func Open():
	if trader and M.active() and trader.has_method("BT_SetTab"):
		bt_view = "supply"
		bt_supply_tab = "goods"
		bt_repair_mode = false
		trader.BT_SetTab("goods")
	super()
	if trader and M.active() and trader.has_method("BT_SetTab"):
		_bt_setup()
		_bt_refresh_panel()


func _bt_setup() -> void:
	if bt_ready and is_instance_valid(bt_stock_button):
		return
	bt_ready = true
	var buttons: GridContainer = traderUI.get_node("Panel/Buttons")
	buttons.columns = 4
	bt_stock_button = _bt_button_like(supplyButton, "Stock", buttons)
	buttons.move_child(bt_stock_button, 1)
	bt_stock_button.pressed.connect(BT_ShowStock)
	bt_dailies_button = _bt_button_like(supplyButton, "Dailies", buttons)
	bt_dailies_button.pressed.connect(BT_ShowDailies)

	# Goods / Furniture tabs, right of the Supply header
	var header: Control = supplyUI.get_node("Header")
	var group := ButtonGroup.new()
	var x := header.position.x + header.size.x + 6.0
	for t in ["Goods", "Furniture"]:
		var b := _bt_button_like(supplyButton, t, supplyUI)
		b.button_group = group
		b.position = Vector2(x, header.position.y)
		b.size = Vector2(104, header.size.y)
		x += 108.0
		b.pressed.connect(BT_SetSupplyTab.bind(t.to_lower()))
		if t == "Goods":
			bt_goods_tab = b
		else:
			bt_furniture_tab = b

	# Reputation line under the trader's stats
	var stats: Control = traderUI.get_node("Panel/Stats")
	bt_rep_line = stats.get_node("Tasks").duplicate()
	bt_rep_line.name = "BT_Rep"
	bt_rep_line.text = "Rep:"
	stats.add_child(bt_rep_line)

	# Repair toggle in the deal panel
	var deal: GridContainer = dealUI.get_node("Panel/Buttons")
	bt_repair_button = _bt_button_like(resetButton, "Repair", deal)
	bt_repair_button.toggle_mode = true
	bt_repair_button.toggled.connect(_bt_on_repair_toggled)

	var keys: Node = Hotkeys.new()
	keys.name = "BT_Hotkeys"
	keys.interface = self
	add_child(keys)


func _bt_button_like(model: Button, text: String, parent: Node) -> Button:
	var b: Button = model.duplicate(0)   # theme and size, without the signals
	b.name = text
	b.text = text
	b.disabled = false
	b.button_pressed = false
	parent.add_child(b)
	return b


# Labels, buttons and tabs for the trader that's open.
func _bt_refresh_panel() -> void:
	if not bt_ready or trader == null:
		return
	bt_stock_button.visible = M.on("stock")
	bt_dailies_button.visible = M.on("dailies")
	(traderUI.get_node("Panel/Buttons") as GridContainer).columns = 2 + int(bt_stock_button.visible) + int(bt_dailies_button.visible)
	var tabs: bool = M.on("tabs") and bt_view == "supply" and supplyUI.visible
	bt_goods_tab.visible = tabs
	bt_furniture_tab.visible = tabs
	bt_goods_tab.set_pressed_no_signal(bt_supply_tab == "goods")
	bt_furniture_tab.set_pressed_no_signal(bt_supply_tab == "furniture")
	bt_rep_line.visible = M.on("reputation")
	var value: Label = bt_rep_line.get_node("Value")
	value.text = M.rep_text(trader)
	var repairs := not M.repair_types(trader).is_empty()
	bt_repair_button.visible = repairs
	(dealUI.get_node("Panel/Buttons") as GridContainer).columns = 3 if repairs else 2
	bt_repair_button.set_pressed_no_signal(bt_repair_mode)
	supplyUI.get_node("Header/Label").text = "Stock" if bt_view == "stock" else "Supply"
	tasksUI.get_node("Header/Label").text = "Dailies" if bt_view == "dailies" else "Tasks"


# ---------------------------------------------------------------- views

func _on_supply_pressed() -> void:
	super()
	if trader and M.active() and trader.has_method("BT_SetTab"):
		bt_view = "supply"
		trader.BT_SetTab(bt_supply_tab)
		Resupply()
		_bt_refresh_panel()


func _on_tasks_pressed() -> void:
	super()
	if trader and M.active():
		bt_view = "tasks"
		_bt_refresh_panel()


func BT_SetSupplyTab(tab: String) -> void:
	if trader == null or not trader.has_method("BT_SetTab"):
		return
	bt_supply_tab = tab
	trader.BT_SetTab(tab)
	Resupply()
	_bt_refresh_panel()
	PlayClick()


func BT_ShowStock() -> void:
	if trader == null or not trader.has_method("BT_SetTab"):
		return
	supplyUI.show()
	tasksUI.hide()
	ResetInput()
	bt_view = "stock"
	trader.BT_SetTab("stock")
	Resupply()
	_bt_refresh_panel()
	PlayClick()


func BT_ShowDailies() -> void:
	if trader == null:
		return
	supplyUI.hide()
	tasksUI.show()
	ResetInput()
	ResetTrading()
	bt_view = "dailies"
	BT_FillDailies()
	_bt_refresh_panel()
	PlayClick()


func BT_FillDailies() -> void:
	for element in taskList.get_children():
		element.queue_free()
	for td in M.dailies_for(trader):
		var row = task.instantiate()
		row.set_script(DailyRow)
		taskList.add_child(row)
		row.Initialize(td, self)
		row.BT_Setup(M.daily_done(trader, td))


# Restock now (hotkey). Respects the cooldown setting.
func BT_Refresh() -> void:
	if trader == null or not trader.has_method("BT_Refresh"):
		return
	var wait: float = trader.BT_Refresh()
	if wait > 0.0:
		PlayError()
		Loader.Message("%s restocks again in %d:%02d" % [trader.traderData.name, int(wait) / 60, int(wait) % 60], Color.ORANGE)
		return
	if supplyUI.visible:
		Resupply()
	trader.PlayTraderReset()
	Loader.Message("%s restocked" % trader.traderData.name, Color.GREEN)


# ---------------------------------------------------------------- tasks

func Complete(data: Resource):
	if data is TaskData and data.has_meta("bt_daily"):
		_bt_complete_daily(data)
		return
	var before: int = M.level(trader) if trader else 0
	super(data)
	if data is TaskData and trader and M.active():
		M.announce(trader, before)
		_bt_refresh_panel()


func _bt_complete_daily(td: TaskData) -> void:
	if trader == null or M.daily_done(trader, td):
		return
	DestroyInputItems(td)
	for item in td.receive:
		var sd := M.make_slot(item)
		if not AutoStack(sd, inventoryGrid):
			Create(sd, inventoryGrid, true)
	M.mark_daily_done(trader, td)
	M.add_rep(trader, M.daily_points(td))
	ResetInput()
	trader.PlayTraderTask()
	Loader.Message("Daily completed: " + td.name.trim_suffix(" [Daily]"), Color.GREEN)
	BT_FillDailies()
	_bt_refresh_panel()


# ---------------------------------------------------------------- deals

func _bt_on_repair_toggled(on: bool) -> void:
	bt_repair_mode = on
	PlayClick()


func _bt_repairable(item) -> bool:
	if item == null or item.get_parent() != inventoryGrid or trader == null:
		return false
	var types := M.repair_types(trader)
	var data = item.slotData.itemData
	return data and (str(data.type) in types) and float(item.slotData.condition) < 100.0


# In repair mode, clicking one of your items marks it for repair instead of
# offering it.
func TradeSelection():
	if bt_repair_mode and hoverItem and hoverItem.get_parent() == inventoryGrid and M.active():
		if hoverItem.selected:
			hoverItem.State("Static")
		if hoverItem.get_meta("bt_repair", false):
			_bt_mark_repair(hoverItem, false)
			PlayClick()
		elif _bt_repairable(hoverItem):
			_bt_mark_repair(hoverItem, true)
			PlayClick()
		else:
			PlayError()
		CalculateDeal()
		return
	if hoverItem and hoverItem.get_meta("bt_repair", false):
		_bt_mark_repair(hoverItem, false)
	super()


func _bt_mark_repair(item, on: bool) -> void:
	item.set_meta("bt_repair", on)
	var tint = item.get_node_or_null("BT_RepairTint")
	if on and tint == null:
		tint = ColorRect.new()
		tint.name = "BT_RepairTint"
		tint.color = Color(0.25, 0.55, 1.0, 0.22)
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tint.set_anchors_preset(Control.PRESET_FULL_RECT)
		item.add_child(tint)
	if tint:
		tint.visible = on


func _bt_repairs() -> Array:
	var out := []
	for element in inventoryGrid.get_children():
		if element.get_meta("bt_repair", false):
			out.append(element)
	return out


func ResetTrading():
	for element in _bt_repairs():
		_bt_mark_repair(element, false)
	super()


# The game's deal maths, plus fixed prices (the trader's key) and repairs.
func CalculateDeal():
	if not M.active() or trader == null:
		super()
		return
	var request := 0.0
	var offer := 0.0
	for element in supplyGrid.get_children():
		if element.selected:
			var price := M.key_price(trader, element.slotData.itemData)
			request += price if price >= 0 else element.Value() * (trader.tax * 0.01 + 1)
	for element in _bt_repairs():
		request += M.repair_cost(trader, element.slotData)
	for element in inventoryGrid.get_children():
		if element.selected:
			offer += element.Value()
	requestValue.text = str(int(round(request)))
	offerValue.text = str(int(round(offer)))
	if offer == 0 and request == 0:
		resetButton.disabled = true
		acceptButton.disabled = true
		dealSlider.value = 1.0
	elif offer == request:
		resetButton.disabled = false
		acceptButton.disabled = false
		dealSlider.value = 1.0
	elif offer != 0 and request == 0:
		acceptButton.disabled = true
		resetButton.disabled = false
		dealSlider.value = 2
	elif offer == 0:
		acceptButton.disabled = true
		resetButton.disabled = false
		dealSlider.value = 0
	else:
		acceptButton.disabled = offer < request
		resetButton.disabled = false
		dealSlider.value = offer / request


func CompleteDeal():
	if not M.active() or trader == null:
		super()
		return
	var traded := float(requestValue.text)
	var repairs := _bt_repairs()
	super()
	for element in repairs:
		if is_instance_valid(element):
			element.slotData.condition = 100.0
			element.UpdateDetails()
			_bt_mark_repair(element, false)
	if not repairs.is_empty():
		Loader.Message("Repaired %d item(s)" % repairs.size(), Color.GREEN)
	M.add_rep(trader, traded / M.VALUE_PER_POINT)
	_bt_refresh_panel()
