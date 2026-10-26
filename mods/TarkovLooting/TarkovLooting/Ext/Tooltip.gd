# Tarkov Looting: unknown items only show a name placeholder.
extends "res://Scripts/Tooltip.gd"

const TL = preload("res://TarkovLooting/TL.gd")


func Update(item: Item):
	if not TL.is_unknown(item):
		super(item)
		return
	Reset()
	title.show()
	title.text = "Unknown item"
	type.show()
	type.text = "Right-click > Examine"
	rarity.hide()
	if item.interface and item.interface.has_method("TL_IsExamining") and item.interface.TL_IsExamining(item):
		type.text = "Examining..."
	panel.size = Vector2(256, 0)
	interface.tooltipOffset = panel.size.y / 2.0
