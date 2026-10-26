# Self-test for Cash Money (cs_cash_money). r is the CSTest runner.
extends RefCounted

const CM = preload("res://CSCashMoney/Mod.gd")


func run(r) -> void:
	r.check("CashMoney: active", CM.active())
	var euro := CM.euro()
	r.check("CashMoney: banknote item with icon", euro.icon != null and euro.tetris != null and euro.stackable)
	var db = r.get_node("/root/Database")
	var scene = db.get(CM.FILE)
	r.check("CashMoney: the game's Database finds it", scene is PackedScene)
	r.check("CashMoney: vanilla items still found", db.get("Potato") is PackedScene)
	if scene is PackedScene:
		var p = scene.instantiate()
		r.get_tree().current_scene.add_child(p)
		r.check("CashMoney: a bundle can lie in the world", p is Pickup and CM.is_cash(p.slotData.itemData) and p.mesh != null)
		p.queue_free()

	var interface = r.get_node("/root/Map/Core/UI/Interface")
	if Engine.get_meta("Cleanstrike").is_loaded("tarkov_looting"):
		load("res://TarkovLooting/TL.gd").learn(CM.FILE)
	interface.Create(CM.stack(100), interface.inventoryGrid, false)
	await r.wait(0.3)
	var cash = null
	for c in interface.inventoryGrid.get_children():
		if c is Item and CM.is_cash(c.slotData.itemData):
			cash = c
	r.check("CashMoney: cash in the inventory", cash != null)
	if cash:
		r.check("CashMoney: worth its amount", cash.Value() == 100)
		r.check("CashMoney: inventory total", interface.CM_Total() == 100)
		var old = interface.trader
		interface.trader = interface   # any trader: only "trading now" matters
		r.check("CashMoney: buys 20% less when trading", cash.Value() == 83, str(cash.Value()))
		interface.trader = old
		cash.queue_free()

	var box := Node3D.new()
	box.set_script(load("res://Scripts/LootContainer.gd"))
	box.civilian = true
	CM.overrides = {"container_chance": 100.0}
	r.get_tree().current_scene.add_child(box)
	await r.wait(0.1)
	var found := false
	for sd in box.loot:
		found = found or CM.is_cash(sd.itemData)
	r.check("CashMoney: containers can hold cash", found)
	CM.overrides = {}
	box.queue_free()
