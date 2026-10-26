# Better Map: drawn on top of the world map (in map pixels, so it zooms
# with it): you-are-here, shelters per area, traders you have met.
extends Control

const M = preload("res://CSBetterMap/Mod.gd")
const YOU := Color(0.95, 0.75, 0.25)
const SHELTER := Color(0.75, 0.9, 0.75)
const TRADER := Color(0.6, 0.8, 1.0)

var here := ""        # area marker the player is in
var here_label := ""
var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	t += delta
	if is_visible_in_tree():
		queue_redraw()


func _marker(area: String) -> Vector2:
	var m = get_parent().get_node_or_null(area)
	return m.position if m else Vector2(-1, -1)


func _text(at: Vector2, s: String, col: Color, size := 26) -> void:
	var font := ThemeDB.fallback_font
	draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, 0.75))
	draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw() -> void:
	var lines := M.lines()
	for area in lines:
		var p := _marker(area)
		if p.x < 0:
			continue
		var y := p.y + 62.0
		for entry in lines[area]:
			var col: Color = SHELTER if entry[0] == "shelter" else TRADER
			var icon := "■ " if entry[0] == "shelter" else "● "
			_text(Vector2(p.x - 40, y), icon + str(entry[1]), col, 24)
			y += 30.0
	if bool(M.setting("you")) and here != "":
		var p := _marker(here)
		if p.x >= 0:
			var pulse := 0.5 + 0.5 * sin(t * 4.0)
			draw_arc(p, 34.0 + 10.0 * pulse, 0.0, TAU, 48, Color(YOU, 0.9 - 0.5 * pulse), 5.0)
			draw_circle(p, 9.0, YOU)
			_text(Vector2(p.x + 44, p.y - 30), here_label, YOU, 28)
