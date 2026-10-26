# Cash Money: your total cash, top right of the inventory.
extends "res://Scripts/Interface.gd"

const CM = preload("res://CSCashMoney/Mod.gd")

var cm_label: Label
var cm_wait := 0.0


func _physics_process(delta):
	super(delta)
	cm_wait -= delta
	if cm_wait > 0.0:
		return
	cm_wait = 0.25
	var show: bool = CM.active() and bool(CM.setting("show_total")) and is_visible_in_tree()
	if not show:
		if cm_label:
			cm_label.hide()
		return
	if cm_label == null:
		cm_label = Label.new()
		cm_label.name = "CS_CashTotal"
		cm_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cm_label.add_theme_font_size_override("font_size", 16)
		cm_label.add_theme_color_override("font_color", Color(0.75, 0.9, 0.75))
		cm_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		cm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cm_label.position = Vector2(-220, 12)
		cm_label.size = Vector2(200, 24)
		add_child(cm_label)
	cm_label.text = "€ %d" % CM_Total()
	cm_label.show()


func CM_Total() -> int:
	var n := 0
	for c in inventoryGrid.get_children():
		if c is Item and c.slotData and CM.is_cash(c.slotData.itemData):
			n += int(c.slotData.amount)
	return n
