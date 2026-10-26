# Item Clarity: task needs refresh when the inventory opens; hovering a
# weapon, magazine or round highlights what goes with it.
extends "res://Scripts/Interface.gd"

const IC = preload("res://CSItemClarity/Mod.gd")

var ic_hovered = null
var ic_lit: Array = []


func Open():
	if IC.active():
		IC.refresh_tasks()
	super()


func Hover():
	super()
	if not IC.on("highlight_compatible"):
		return
	var h = hoverItem if hoverItem and not itemDragged and not IC.hidden(hoverItem) else null
	if h != ic_hovered:
		ic_hovered = h
		IC_Highlight(h)


func IC_Highlight(h) -> void:
	for n in ic_lit:
		if is_instance_valid(n):
			n.queue_free()
	ic_lit = []
	if h == null or h.slotData == null:
		return
	var data = h.slotData.itemData
	for grid in [inventoryGrid, containerGrid, supplyGrid]:
		if grid == null:
			continue
		for c in grid.get_children():
			if c is Item and c != h and c.slotData and not IC.hidden(c) \
					and (IC.goes_with(data, c.slotData.itemData) or IC.goes_with(c.slotData.itemData, data)):
				var glow := ColorRect.new()
				glow.name = "CS_ICGlow"
				glow.color = Color(0.45, 0.9, 0.45, 0.22)
				glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
				glow.set_anchors_preset(Control.PRESET_FULL_RECT)
				c.add_child(glow)
				ic_lit.append(glow)
