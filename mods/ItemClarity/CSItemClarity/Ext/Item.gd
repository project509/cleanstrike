# Item Clarity: a task marker on items an open task asks for (green once
# you carry enough).
extends "res://Scripts/Item.gd"

const IC = preload("res://CSItemClarity/Mod.gd")


func UpdateDetails():
	super()
	IC_Mark()


func Display(source, data, showReturns: bool):
	super(source, data, showReturns)
	IC_Mark()


func IC_Mark() -> void:
	var mark = get_node_or_null("CS_ICTask")
	var show := IC.on("task_markers") and slotData and slotData.itemData and not IC.hidden(self)
	var need := 0
	if show:
		IC.ensure_tasks()
		need = IC.most_needed(slotData.itemData.file)
	if need == 0:
		if mark:
			mark.hide()
		return
	if mark == null:
		mark = Label.new()
		mark.name = "CS_ICTask"
		mark.text = "!"
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.add_theme_font_size_override("font_size", 14)
		mark.add_theme_constant_override("outline_size", 4)
		mark.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		mark.position = Vector2(4, 0)
		add_child(mark)
	var enough := IC.owned(interface, slotData.itemData.file) >= need
	mark.modulate = Color(0.45, 0.9, 0.45) if enough else Color(1.0, 0.8, 0.3)
	mark.show()
