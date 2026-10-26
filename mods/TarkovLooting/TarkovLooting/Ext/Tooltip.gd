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
	type.text = "Not examined  ·  middle-click to examine"
	if not bool(TL.setting("examine_middle_mouse")):
		type.text = "Not examined  ·  right-click > Examine"
	rarity.hide()
	var ui = item.interface
	if ui and ui.has_method("TL_ExamineProgress"):
		var p: float = ui.TL_ExamineProgress(item)
		if p >= 0.0:
			type.text = "Examining...  %d%%" % int(p * 100.0)
	panel.size = Vector2(256, 0)
	interface.tooltipOffset = panel.size.y / 2.0
