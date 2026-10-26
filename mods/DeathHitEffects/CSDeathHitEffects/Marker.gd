# Death and Hit Effects: the hit marker, a small X around the crosshair
# (white on a hit, red on a kill) that fades out.
extends Control

const LIFE := 0.35

var t := LIFE
var kill := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_hit(is_kill: bool) -> void:
	t = 0.0
	kill = is_kill


func _process(delta: float) -> void:
	if t < LIFE:
		t += delta
		queue_redraw()


func _draw() -> void:
	if t >= LIFE:
		return
	var c := get_viewport_rect().size / 2.0
	var a := 1.0 - t / LIFE
	var col := Color(1.0, 0.15, 0.1, a) if kill else Color(1, 1, 1, a * 0.9)
	var inner := 6.0
	var outer := 14.0 if kill else 11.0
	for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var n: Vector2 = d.normalized()
		draw_line(c + n * inner, c + n * outer, Color(0, 0, 0, a * 0.5), 4.0)
		draw_line(c + n * inner, c + n * outer, col, 2.0)
