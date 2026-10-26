# Item Clarity: task, crafting and price-per-slot lines under the tooltip.
extends "res://Scripts/Tooltip.gd"

const IC = preload("res://CSItemClarity/Mod.gd")


func Reset():
	super()
	for l in _ic_lines():
		l.queue_free()


func Update(item: Item):
	super(item)
	if not IC.active() or IC.hidden(item):
		return
	var elements = info.get_parent()
	for line in IC.tooltip_lines(item.slotData.itemData, item.interface):
		var l = info.duplicate()
		l.name = "CS_IC"
		l.set_meta("cs_ic", true)
		l.text = line[0]
		l.modulate = line[1]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.show()
		elements.add_child(l)
	panel.size = Vector2(256, 0)
	interface.tooltipOffset = panel.size.y / 2.0


func _ic_lines() -> Array:
	var out := []
	if info:
		for c in info.get_parent().get_children():
			if c.has_meta("cs_ic"):
				out.append(c)
	return out
