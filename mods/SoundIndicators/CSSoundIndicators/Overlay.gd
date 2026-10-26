# Sound Indicators: markers on a ring around the screen centre, pointing at
# where a sound came from (relative to where you're looking), fading out.
extends Control

const M = preload("res://CSSoundIndicators/Mod.gd")
const LIFE := {"shot": 2.5, "step": 1.2}
const COLOR := {"shot": Color(1.0, 0.55, 0.15), "step": Color(0.92, 0.92, 0.88)}

var marks: Array = []   # {kind, at, t}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 30


func add_mark(kind: String, at: Vector3) -> void:
	for m in marks:   # one marker per spot and kind: refresh it
		if m.kind == kind and m.at.distance_to(at) < 2.0:
			m.at = at
			m.t = 0.0
			return
	marks.append({"kind": kind, "at": at, "t": 0.0})


func _process(delta: float) -> void:
	for m in marks:
		m.t += delta
	marks = marks.filter(func(m): return m.t < LIFE[m.kind])
	visible = not marks.is_empty()
	if visible:
		queue_redraw()


# Angle of a world point around you (0 = straight ahead, clockwise).
func angle_to(at: Vector3) -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 0.0
	var local := cam.global_transform.affine_inverse() * at
	return atan2(local.x, -local.z)


func _draw() -> void:
	var c := get_viewport_rect().size / 2.0   # not size: the overlay can end up 0x0
	var r := float(M.setting("circle_size"))
	var s := float(M.setting("icon_size"))
	for m in marks:
		var a := angle_to(m.at)
		var dir := Vector2(sin(a), -cos(a))
		var p := c + dir * r
		var col: Color = COLOR[m.kind]
		col.a = clampf(1.0 - m.t / LIFE[m.kind], 0.0, 1.0) * 0.9
		if m.kind == "shot":
			var side := Vector2(-dir.y, dir.x)
			draw_colored_polygon(PackedVector2Array([p + dir * s, p - dir * s * 0.4 + side * s * 0.6, p - dir * s * 0.4 - side * s * 0.6]), col)
		else:
			draw_circle(p, s * 0.35, col)
