# Road to Tarkov: adds "Examine" to the right-click menu of unknown items and
# hides actions that need the item identified first.
extends "res://Scripts/Context.gd"

const RTT = preload("res://RoadToTarkov/RTT.gd")

var rtt_examine: Button


func Update(slotData: SlotData):
	super(slotData)
	if not RTT.looting():
		return
	_rtt_ensure_button()
	var item = interface.contextItem
	if not RTT.is_unknown(item):
		rtt_examine.hide()
		return
	for b in [useButton, equipButton, unloadButton, sleepButton]:
		b.hide()
	for i in 4:
		var rb = buttons.get_node_or_null("Remove_" + str(i))
		if rb:
			rb.hide()
	var busy: bool = interface.has_method("RTT_IsExamining") and interface.RTT_IsExamining(item)
	rtt_examine.text = "Examining..." if busy else "Examine"
	rtt_examine.disabled = busy
	rtt_examine.show()
	buttons.move_child(rtt_examine, 0)
	# Re-run the game's own sizing now that the button set changed.
	panel.size = Vector2(80.0, 0.0)
	panel.global_position = get_global_mouse_position() - Vector2(0, panel.size.y)
	centerPosition = get_global_mouse_position() - Vector2(-panel.size.x / 2, panel.size.y / 2)


func _rtt_ensure_button() -> void:
	if rtt_examine and is_instance_valid(rtt_examine):
		return
	# Copy an existing button so it matches the game's theme, without its signals.
	rtt_examine = useButton.duplicate(0)
	rtt_examine.name = "RTT_Examine"
	rtt_examine.disabled = false
	rtt_examine.pressed.connect(_rtt_on_examine)
	buttons.add_child(rtt_examine)
	rtt_examine.hide()


func _rtt_on_examine() -> void:
	if interface.visible and interface.has_method("RTT_ContextExamine"):
		interface.RTT_ContextExamine()
