# Road to Tarkov: inventory cell look (Tarkov tints, short name top-right,
# unknown-item silhouette, examine progress bar).
extends "res://Scripts/Item.gd"

const RTT = preload("res://RoadToTarkov/RTT.gd")

var rtt_mark: Label
var rtt_bar: ColorRect
var rtt_bar_bg: ColorRect
var rtt_styled := false


func UpdateDetails():
	super()
	if RTT.active():
		_rtt_refresh()


func State(state):
	super(state)
	if RTT.active() and state == "Static" and bool(RTT.setting("item_colors")) and slotData and slotData.itemData:
		fill.color = RTT.tint_for(slotData.itemData)


func _rtt_refresh() -> void:
	if not rtt_styled:
		rtt_styled = true
		# Tarkov puts the short name in the top-right corner of the cell.
		abbreviation.anchor_left = 0.0
		abbreviation.anchor_right = 1.0
		abbreviation.offset_left = 3.0
		abbreviation.offset_right = -3.0
		abbreviation.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var unknown := RTT.is_unknown(self)
	if unknown:
		_rtt_ensure_mark()
		abbreviation.text = "?"
		condition.hide()
		if not slotData.itemData.stackable:
			amount.hide()
		for symbol in symbols.get_children():
			symbol.hide()
	if rtt_mark:
		rtt_mark.visible = unknown
		rtt_mark.size = size
	if sprite:
		sprite.modulate = Color(0.06, 0.06, 0.06, 0.9) if unknown else Color.WHITE


func _rtt_ensure_mark() -> void:
	if rtt_mark:
		return
	rtt_mark = Label.new()
	rtt_mark.name = "RTT_Unknown"
	rtt_mark.text = "?"
	rtt_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rtt_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rtt_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtt_mark.add_theme_font_size_override("font_size", 28)
	rtt_mark.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8, 0.85))
	rtt_mark.add_theme_color_override("font_outline_color", Color.BLACK)
	rtt_mark.add_theme_constant_override("outline_size", 6)
	rtt_mark.size = size
	add_child(rtt_mark)


# Examine progress, 0..1. A negative value removes the bar.
func RTT_SetProgress(p: float) -> void:
	if p < 0.0:
		if rtt_bar:
			rtt_bar_bg.queue_free()
			rtt_bar = null
			rtt_bar_bg = null
		return
	if rtt_bar == null:
		rtt_bar_bg = ColorRect.new()
		rtt_bar_bg.color = Color(0, 0, 0, 0.6)
		rtt_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rtt_bar_bg)
		rtt_bar = ColorRect.new()
		rtt_bar.color = Color(0.85, 0.75, 0.35, 0.95)
		rtt_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtt_bar_bg.add_child(rtt_bar)
	rtt_bar_bg.position = Vector2(4, size.y - 9)
	rtt_bar_bg.size = Vector2(size.x - 8, 5)
	rtt_bar.size = Vector2((size.x - 8) * clampf(p, 0.0, 1.0), 5)
