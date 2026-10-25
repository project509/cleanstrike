# Road to Tarkov: destination picker shown at every School travel point.
# Built in code from the game's own theme, font and icons so it reads as
# part of Vostok's UI. Emits `chosen("School" | "Customs")` or `cancelled`.
extends Control

signal chosen(map_name: String)
signal cancelled

const DIR := "res://RoadToTarkov/Customs/"
const DESTINATIONS := [
	{"map": "School", "zone": "Area 05", "thumb": "school_thumb.jpg", "note": "", "badge": ""},
	{"map": "Customs", "zone": "Area 05", "thumb": "customs_thumb.jpg", "note": "Map art: re3mr.com  ·  CC BY-NC-SA 4.0", "badge": "PREVIEW"},
]

var _transition
var _cards: Array[PanelContainer] = []
var _done := false
var _style_idle: StyleBoxFlat
var _style_hover: StyleBoxFlat


static func load_texture(path: String) -> Texture2D:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var img := Image.new()
	var err := img.load_jpg_from_buffer(bytes) if path.ends_with(".jpg") else img.load_png_from_buffer(bytes)
	return ImageTexture.create_from_image(img) if err == OK else null


func setup(transition) -> void:
	_transition = transition
	name = "RTT_DestinationPicker"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists("res://UI/Themes/Theme.tres"):
		theme = load("res://UI/Themes/Theme.tres")

	_style_idle = _box(Color(0.06, 0.065, 0.06, 0.96), Color(1, 1, 1, 0.10))
	_style_hover = _box(Color(0.09, 0.095, 0.09, 0.98), Color(1, 1, 1, 0.70))

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	column.add_child(_label("SELECT DESTINATION", 30, Color(0.92, 0.92, 0.88), HORIZONTAL_ALIGNMENT_CENTER))
	var from: String = str(transition.currentMap) if transition and str(transition.currentMap) != "" else "here"
	column.add_child(_label("The road past the school forks. Leaving %s." % from, 15, Color(0.62, 0.63, 0.60), HORIZONTAL_ALIGNMENT_CENTER))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	column.add_child(spacer)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	for i in DESTINATIONS.size():
		row.add_child(_card(DESTINATIONS[i], i))

	var hint := _label("Click a destination  ·  1 / 2 to choose  ·  Esc to stay", 13, Color(0.5, 0.51, 0.49), HORIZONTAL_ALIGNMENT_CENTER)
	hint.custom_minimum_size = Vector2(0, 40)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	column.add_child(hint)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)


func _card(d: Dictionary, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Card_" + d.map
	card.add_theme_stylebox_override("panel", _style_idle)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.mouse_entered.connect(func(): card.add_theme_stylebox_override("panel", _style_hover))
	card.mouse_exited.connect(func(): card.add_theme_stylebox_override("panel", _style_idle))
	card.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_choose(d.map))
	_cards.append(card)

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)

	# Thumbnail with a thin frame, plus an optional badge in the corner.
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(480, 270)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(frame)
	var tex := TextureRect.new()
	tex.texture = load_texture(DIR + d.thumb)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(tex)
	if d.badge != "":
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", _box(Color(0.80, 0.62, 0.20, 0.95), Color(0, 0, 0, 0), 6, 2))
		badge.position = Vector2(10, 10)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(_label(d.badge, 11, Color(0.08, 0.06, 0.02)))
		frame.add_child(badge)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var title := _label(d.map, 24, Color(0.93, 0.93, 0.90))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var key := PanelContainer.new()
	key.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.25), 8, 1))
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.add_child(_label(str(index + 1), 13, Color(0.75, 0.76, 0.73)))
	head.add_child(key)

	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 18)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(info)
	info.add_child(_label(d.zone, 14, Color(0.55, 0.75, 0.55)))
	var t: float = float(_transition.time) if _transition else 1.0
	if t > 0.0:
		info.add_child(_cost("res://UI/Sprites/Icon_Time.png", "+%dh" % int(t)))
		info.add_child(_cost("res://UI/Sprites/Icon_Energy.png", "-%d" % int(t * 5.0)))
		info.add_child(_cost("res://UI/Sprites/Icon_Dehydration.png", "-%d" % int(t * 10.0)))

	var note := _label(d.note, 11, Color(0.45, 0.46, 0.44))
	note.custom_minimum_size = Vector2(0, 16)
	col.add_child(note)
	return card


func _cost(icon_path: String, text: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color(0.8, 0.8, 0.78)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
	box.add_child(_label(text, 14, Color(0.80, 0.80, 0.77)))
	return box


func _label(text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box(bg: Color, border: Color, pad_h := 0, pad_v := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1 if border.a > 0.0 else 0)
	s.set_corner_radius_all(2)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s


func _input(event: InputEvent) -> void:
	if _done or not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_cancel()
			KEY_1, KEY_KP_1:
				_choose(DESTINATIONS[0].map)
			KEY_2, KEY_KP_2:
				_choose(DESTINATIONS[1].map)
			_:
				return
		get_viewport().set_input_as_handled()


func _choose(map_name: String) -> void:
	if _done:
		return
	_done = true
	chosen.emit(map_name)
	queue_free()


func _cancel() -> void:
	if _done:
		return
	_done = true
	cancelled.emit()
	queue_free()


# Used by the self-test.
func choose(map_name: String) -> void:
	_choose(map_name)
