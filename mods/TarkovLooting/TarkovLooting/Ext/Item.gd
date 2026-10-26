# Tarkov Looting: inventory cell look (Tarkov tints, short name top-right,
# unknown-item silhouette, examine progress bar).
extends "res://Scripts/Item.gd"

const TL = preload("res://TarkovLooting/TL.gd")

var tl_mark: Label
var tl_bar: ColorRect
var tl_bar_bg: ColorRect
var tl_styled := false


func UpdateDetails():
	super()
	if TL.active():
		_tl_refresh()


func State(state):
	super(state)
	if TL.active() and state == "Static" and bool(TL.setting("item_colors")) and slotData and slotData.itemData:
		fill.color = TL.tint_for(slotData.itemData)


func _tl_refresh() -> void:
	if not tl_styled:
		tl_styled = true
		# Tarkov puts the short name in the top-right corner of the cell.
		abbreviation.anchor_left = 0.0
		abbreviation.anchor_right = 1.0
		abbreviation.offset_left = 3.0
		abbreviation.offset_right = -3.0
		abbreviation.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var unknown := TL.is_unknown(self)
	if unknown:
		_tl_ensure_mark()
		abbreviation.text = "?"
		condition.hide()
		if not slotData.itemData.stackable:
			amount.hide()
		for symbol in symbols.get_children():
			symbol.hide()
	if tl_mark:
		tl_mark.visible = unknown
		tl_mark.size = size
	if sprite:
		sprite.modulate = Color(0.06, 0.06, 0.06, 0.9) if unknown else Color.WHITE


func _tl_ensure_mark() -> void:
	if tl_mark:
		return
	tl_mark = Label.new()
	tl_mark.name = "TL_Unknown"
	tl_mark.text = "?"
	tl_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl_mark.add_theme_font_size_override("font_size", 28)
	tl_mark.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8, 0.85))
	tl_mark.add_theme_color_override("font_outline_color", Color.BLACK)
	tl_mark.add_theme_constant_override("outline_size", 6)
	tl_mark.size = size
	add_child(tl_mark)


# Examine progress, 0..1. A negative value removes the bar.
func TL_SetProgress(p: float) -> void:
	if p < 0.0:
		if tl_bar:
			tl_bar_bg.queue_free()
			tl_bar = null
			tl_bar_bg = null
		return
	if tl_bar == null:
		tl_bar_bg = ColorRect.new()
		tl_bar_bg.color = Color(0, 0, 0, 0.6)
		tl_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tl_bar_bg)
		tl_bar = ColorRect.new()
		tl_bar.color = Color(0.85, 0.75, 0.35, 0.95)
		tl_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tl_bar_bg.add_child(tl_bar)
	tl_bar_bg.position = Vector2(4, size.y - 9)
	tl_bar_bg.size = Vector2(size.x - 8, 5)
	tl_bar.size = Vector2((size.x - 8) * clampf(p, 0.0, 1.0), 5)
