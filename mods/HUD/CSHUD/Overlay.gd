# CleanStrike HUD: vitals bars (bottom left), compass (top), centre dot and
# fire mode, all drawn in one control over the game's HUD.
extends Control

const H = preload("res://CSHUD/Mod.gd")
const BARS := [["health", "HP", Color(0.85, 0.3, 0.28)], ["energy", "FOOD", Color(0.85, 0.65, 0.3)],
	["hydration", "WATER", Color(0.35, 0.65, 0.9)], ["mental", "MIND", Color(0.7, 0.55, 0.9)],
	["temperature", "TEMP", Color(0.9, 0.85, 0.55)], ["bodyStamina", "BODY", Color(0.6, 0.85, 0.6)],
	["armStamina", "ARMS", Color(0.6, 0.85, 0.6)]]
const DIRS := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}

var gd = preload("res://Resources/GameData.tres")
var font: Font
var mode_shown := 0.0      # fire mode text visible until (seconds)
var last_mode := -1
var sz := Vector2(1920, 1080)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if gd.firemode != last_mode:
		if last_mode != -1:
			mode_shown = now + 1.5
		last_mode = gd.firemode
	queue_redraw()


func heading() -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 0.0
	var f := -cam.global_transform.basis.z
	return fposmod(rad_to_deg(atan2(f.x, -f.z)), 360.0)


func _text(at: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(font, at, s, align, width, size, 4, Color(0, 0, 0, 0.6))
	draw_string(font, at, s, align, width, size, col)


func _draw() -> void:
	sz = get_viewport_rect().size   # the game's HUD node has no size of its own
	if gd.isDead or gd.decor:
		return
	var s := float(H.setting("scale"))
	if bool(H.setting("bars")):
		_draw_bars(s)
	if bool(H.setting("compass")):
		_draw_compass(s)
	if H.dot_on:
		var c := sz / 2.0
		draw_circle(c, 2.5 * s, Color(0, 0, 0, 0.5))
		draw_circle(c, 1.6 * s, Color(1, 1, 1, 0.9))
	if Time.get_ticks_msec() / 1000.0 < mode_shown and not H.burst_mod_on():
		_text(Vector2(sz.x - 40 * s, sz.y - 40 * s), "AUTO" if gd.firemode == 2 else "SEMI", int(20 * s), Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_RIGHT, 0)


func _draw_bars(s: float) -> void:
	var w := 150.0 * s
	var h := 6.0 * s
	var x := 32.0 * s
	var y := sz.y - 32.0 * s - BARS.size() * 14.0 * s
	for b in BARS:
		var v := clampf(float(gd.get(b[0])) / 100.0, 0.0, 1.0)
		if b[0] in ["bodyStamina", "armStamina", "temperature"] and v >= 0.999 and bool(H.setting("hide_full")):
			continue
		var col: Color = b[2]
		if v < 0.25:
			col = col.lerp(Color(1, 0.2, 0.2), 0.6)
		_text(Vector2(x, y + h + 1), b[1], int(10 * s), Color(1, 1, 1, 0.7))
		var bx := x + 46.0 * s
		draw_rect(Rect2(bx, y, w, h), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(bx, y, w * v, h), col)
		if bool(H.setting("numbers")):
			_text(Vector2(bx + w + 6 * s, y + h + 1), str(int(round(v * 100))), int(10 * s), Color(1, 1, 1, 0.7))
		y += 14.0 * s


func _draw_compass(s: float) -> void:
	var cx := sz.x / 2.0
	var y := 30.0 * s
	var span := 360.0 * s     # pixels across the tape
	var fov := 120.0          # degrees across the tape
	var hdg := heading()
	draw_rect(Rect2(cx - span / 2, y - 14 * s, span, 26 * s), Color(0, 0, 0, 0.25))
	for d in range(0, 360, 15):
		var off := wrapf(d - hdg, -180.0, 180.0)
		if absf(off) > fov / 2:
			continue
		var px := cx + off / fov * span
		var a := 1.0 - absf(off) / (fov / 2) * 0.8
		if DIRS.has(d):
			_text(Vector2(px - 30 * s, y + 6 * s), DIRS[d], int((16 if d % 90 == 0 else 12) * s), Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 60 * s)
		else:
			draw_line(Vector2(px, y - 8 * s), Vector2(px, y - 2 * s), Color(1, 1, 1, a * 0.7), 1.5)
	draw_line(Vector2(cx, y - 14 * s), Vector2(cx, y - 6 * s), Color(0.95, 0.75, 0.25), 2.0)
	_text(Vector2(cx - 30 * s, y + 26 * s), "%03d" % (int(round(hdg)) % 360), int(11 * s), Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 60 * s)
