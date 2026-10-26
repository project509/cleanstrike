# Tarkov Looting: adds "Examine" to the right-click menu of unknown items and
# hides actions that need the item identified first.
extends "res://Scripts/Context.gd"

const TL = preload("res://TarkovLooting/TL.gd")

var tl_examine: Button


func Update(slotData: SlotData):
	super(slotData)
	if not TL.active():
		return
	_tl_ensure_button()
	var item = interface.contextItem
	if not TL.is_unknown(item):
		tl_examine.hide()
		return
	for b in [useButton, equipButton, unloadButton, sleepButton]:
		b.hide()
	for i in 4:
		var rb = buttons.get_node_or_null("Remove_" + str(i))
		if rb:
			rb.hide()
	var busy: bool = interface.has_method("TL_IsExamining") and interface.TL_IsExamining(item)
	tl_examine.text = "Examining..." if busy else "Examine"
	tl_examine.disabled = busy
	tl_examine.show()
	buttons.move_child(tl_examine, 0)
	# Re-run the game's own sizing now that the button set changed.
	panel.size = Vector2(80.0, 0.0)
	panel.global_position = get_global_mouse_position() - Vector2(0, panel.size.y)
	centerPosition = get_global_mouse_position() - Vector2(-panel.size.x / 2, panel.size.y / 2)


func _tl_ensure_button() -> void:
	if tl_examine and is_instance_valid(tl_examine):
		return
	# Copy an existing button so it matches the game's theme, without its signals.
	tl_examine = useButton.duplicate(0)
	tl_examine.name = "TL_Examine"
	tl_examine.disabled = false
	tl_examine.pressed.connect(_tl_on_examine)
	buttons.add_child(tl_examine)
	tl_examine.hide()


func _tl_on_examine() -> void:
	if interface.visible and interface.has_method("TL_ContextExamine"):
		interface.TL_ContextExamine()
