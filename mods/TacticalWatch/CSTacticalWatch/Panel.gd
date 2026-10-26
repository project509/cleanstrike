# Tactical Watch: the wrist panel (top right), shown with the toggle key while
# the watch is worn.
extends Control

const W = preload("res://CSTacticalWatch/Mod.gd")

var gd = preload("res://Resources/GameData.tres")
var font: Font
var lines: Array = []      # [text, color]
var next_update := 0.0
var was_visible := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font


func _unhandled_input(event: InputEvent) -> void:
	if str(W.setting("mode")) == "toggle" and W.key_event(event):
		W.shown = not W.shown


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var vis := W.visible_now()
	if now >= next_update or vis != was_visible:   # fill at once when shown
		was_visible = vis
		next_update = now + 0.5
		lines = W.panel_lines(self) if vis else []
	queue_redraw()


func _draw() -> void:
	if lines.is_empty() or gd.isDead:
		return
	var vs := get_viewport_rect().size
	var s := float(W.setting("scale"))
	var w := 250.0 * s
	var lh := 20.0 * s
	var x := vs.x - w - 24.0 * s
	var y := 24.0 * s
	draw_rect(Rect2(x - 10 * s, y - 6 * s, w + 20 * s, lines.size() * lh + 14 * s), Color(0.03, 0.05, 0.04, 0.72))
	draw_rect(Rect2(x - 10 * s, y - 6 * s, 3 * s, lines.size() * lh + 14 * s), Color(0.45, 0.85, 0.55, 0.9))
	for i in lines.size():
		var size := int((20 if i == 0 else 14) * s)
		draw_string(font, Vector2(x, y + (i + 1) * lh - 4 * s), lines[i][0], HORIZONTAL_ALIGNMENT_LEFT, w, size, lines[i][1])
