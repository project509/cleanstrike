# Better Traders: each trader keeps three lists (goods, furniture, stock).
# `supply` (the game's list) points at the one being shown, so everything
# the game does with supply (filling the grid, removing what you bought,
# resupplying) works on that tab.
extends "res://Scripts/Trader.gd"

const M = preload("res://CSBetterTraders/Mod.gd")

var bt_goods: Array[SlotData] = []
var bt_furniture: Array[SlotData] = []
var bt_stock: Array[SlotData] = []
var bt_tab := "goods"
var bt_last_refresh := -1.0e12


func CreateSupply():
	if not M.active():
		super()
		return
	bt_goods = []
	bt_furniture = []
	var goods: Array = []
	var furniture: Array = []
	for item in traderBucket:
		if item == null:
			continue
		if M.is_furniture(item) and M.on("tabs"):
			furniture.append(item)
		else:
			goods.append(item)
	if not goods.is_empty():
		for i in int(M.setting("goods_count")):
			bt_goods.append(M.make_slot(goods.pick_random()))
	if not furniture.is_empty():
		for i in int(M.setting("furniture_count")):
			bt_furniture.append(M.make_slot(furniture.pick_random()))
	if M.on("stock"):
		bt_stock = M.make_stock(self)
	else:
		bt_stock = []
	BT_Point()


func BT_Point() -> void:
	match bt_tab:
		"furniture": supply = bt_furniture
		"stock": supply = bt_stock
		_: supply = bt_goods


func BT_SetTab(tab: String) -> void:
	bt_tab = tab
	BT_Point()


# Fresh stock now (the refresh hotkey). Returns seconds left on the cooldown
# instead when it's too soon.
func BT_Refresh() -> float:
	var cooldown := float(M.setting("refresh_cooldown")) * 60.0
	var now := Time.get_ticks_msec() / 1000.0
	if cooldown > 0.0 and now - bt_last_refresh < cooldown:
		return cooldown - (now - bt_last_refresh)
	bt_last_refresh = now
	CreateSupply()
	timer.start()
	return 0.0
