# Tarkov Looting: inventory cell look (Tarkov tints, short name top-right,
# unknown-item silhouette, search preview ghost, examine progress bar).
extends "res://Scripts/Item.gd"

const TL = preload("res://TarkovLooting/TL.gd")

var tl_mark: Label
var tl_bar: ColorRect
var tl_bar_bg: ColorRect
var tl_styled := false
var tl_preview := false
var tl_border: Panel
var tl_state := "Static"


func UpdateDetails():
	super()
	if TL.active():
		_tl_refresh()


func State(state):
	super(state)
	tl_state = state
	if TL.active():
		_tl_apply_fill()


func _tl_apply_fill() -> void:
	if tl_state != "Static" or not slotData or not slotData.itemData:
		return
	# Unknown items and search previews give nothing away: plain cell.
	if TL.is_unknown(self) or tl_preview or not bool(TL.setting("item_colors")):
		fill.color = TL.DEFAULT_TINT
	else:
		fill.color = TL.tint_for(slotData.itemData)


# The next item being searched: a faint grey ghost of its shape, nothing else.
func TL_SetPreview(on: bool) -> void:
	if tl_preview == on:
		return
	tl_preview = on
	_tl_refresh()


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
		tl_mark.visible = unknown and not tl_preview
		tl_mark.size = size
	details.visible = not tl_preview and tl_state != "Free"
	if sprite:
		var mat: Material = null
		if tl_preview:
			mat = TL.silhouette(TL.SILHOUETTE_PREVIEW)
		elif unknown:
			mat = TL.silhouette(TL.SILHOUETTE_UNKNOWN)
		_tl_set_material(sprite, mat)
	_tl_apply_fill()
	_tl_update_border(not unknown and not tl_preview)


# Thin coloured frame for valuable items (value per cell), like Tarkov's
# loot-value overlays. Never shown for unknown items or ghosts.
func _tl_update_border(allowed: bool) -> void:
	var c: Color = TL.value_color(slotData.itemData) if allowed and slotData and slotData.itemData else Color.TRANSPARENT
	if c.a == 0.0:
		if tl_border:
			tl_border.hide()
		return
	if tl_border == null:
		tl_border = Panel.new()
		tl_border.name = "TL_Border"
		tl_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tl_border.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(tl_border)
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(2)
	sb.border_color = Color(c, 0.85)
	tl_border.add_theme_stylebox_override("panel", sb)
	tl_border.show()


# The sprite and its attachment sprites (weapon parts are child sprites).
func _tl_set_material(node: Node, mat: Material) -> void:
	if node is CanvasItem:
		if not node.has_meta("tl_material"):
			node.set_meta("tl_material", [node.material])   # wrapped: null metas are dropped
		node.material = mat if mat else node.get_meta("tl_material")[0]
	for child in node.get_children():
		_tl_set_material(child, mat)


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
