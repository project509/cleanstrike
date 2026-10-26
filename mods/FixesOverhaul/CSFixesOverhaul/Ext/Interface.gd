# Fixes Overhaul, inventory and traders:
#  - Tooltips stay open while the cursor is still on the same item (the game
#    closed them on any 1-pixel mouse move).
#  - Trader tax and tasks are right on the first visit after a map load (the
#    game showed them before the trader's progress had loaded).
#  - FO_CatalogHasRoom, for the full-catalog fix.
extends "res://Scripts/Interface.gd"

const FO = preload("res://CSFixesOverhaul/Mod.gd")

var fo_tip_target = null


func Open():
	super()
	if trader and FO.on("trader_info"):
		var visiting = trader
		await get_tree().create_timer(0.25).timeout
		if trader == visiting and is_instance_valid(visiting) and gameData.isTrading:
			UpdateTraderInfo()
			if has_method("_bt_refresh_panel"):
				call("_bt_refresh_panel")


func _physics_process(delta):
	var was_visible: bool = tooltip.visible
	var before = fo_tip_target
	super(delta)
	if not FO.on("tooltips") or tooltipMode != 1:
		return
	var target = hoverItem if hoverItem else (hoverEquipment if hoverEquipment else hoverInfo)
	if tooltip.visible:
		fo_tip_target = target
	elif was_visible and target != null and target == before and not itemDragged and not context.visible:
		tooltip.global_position = get_global_mouse_position() - Vector2(0, tooltipOffset)
		tooltip.show()
	else:
		fo_tip_target = null


func FO_CatalogHasRoom(item_data) -> bool:
	var w := int(item_data.size.x)
	var h := int(item_data.size.y)
	for y in catalogGrid.gridHeight:
		for x in catalogGrid.gridWidth:
			if catalogGrid.CheckGridSpace(x, y, w, h) or catalogGrid.CheckGridSpace(x, y, h, w):
				return true
	return false
