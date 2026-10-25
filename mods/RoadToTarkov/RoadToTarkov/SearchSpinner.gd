# Road to Tarkov: the rotating "searching" mark drawn over the next cell.
extends Control

var angle := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5


func _process(delta: float) -> void:
	if visible:
		angle = fmod(angle + delta * TAU * 1.2, TAU)
		queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.28
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	draw_arc(c, r, 0.0, TAU, 32, Color(1, 1, 1, 0.12), 3.0, true)
	draw_arc(c, r, angle, angle + TAU * 0.3, 16, Color(0.92, 0.86, 0.62, 0.95), 3.0, true)
