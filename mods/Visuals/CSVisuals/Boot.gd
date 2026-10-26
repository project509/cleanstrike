# Visuals: puts the colour grade on each map's environment and the sharpen
# pass over the 3D view (under the UI). F3 compares with the original.
extends Node

const V = preload("res://CSVisuals/Mod.gd")
const SHARPEN := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.4;
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen, SCREEN_UV).rgb;
	vec3 n = texture(screen, SCREEN_UV + vec2(px.x, 0.0)).rgb + texture(screen, SCREEN_UV - vec2(px.x, 0.0)).rgb
		+ texture(screen, SCREEN_UV + vec2(0.0, px.y)).rgb + texture(screen, SCREEN_UV - vec2(0.0, px.y)).rgb;
	COLOR = vec4(clamp(c + (c * 4.0 - n) * amount, 0.0, 1.0), 1.0);
}
"""

var on := true
var graded_env: Environment
var layer: CanvasLayer


func _ready() -> void:
	if not V.active():
		return
	layer = CanvasLayer.new()
	layer.layer = -1                  # after the 3D view, before the game's UI
	add_child(layer)
	var rect := ColorRect.new()
	rect.name = "Sharpen"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = SHARPEN
	rect.material = mat
	layer.add_child(rect)


func _process(_delta: float) -> void:
	if not V.active():
		return
	var we = get_node_or_null("/root/Map/World/Environment")
	var env: Environment = we.environment if we and "environment" in we else null
	if env and env != graded_env:
		graded_env = env
		apply()
	var amount := float(V.setting("sharpen"))
	layer.visible = on and amount > 0.0 and get_node_or_null("/root/Map") != null
	if layer.visible:
		layer.get_node("Sharpen").material.set_shader_parameter("amount", amount)


func _unhandled_input(event: InputEvent) -> void:
	if V.active() and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == OS.find_keycode_from_string(str(V.setting("compare_key"))):
		on = not on
		apply()


func apply() -> void:
	if graded_env == null:
		return
	var preset := str(V.setting("preset"))
	if on and preset != "None":
		graded_env.adjustment_enabled = true
		graded_env.adjustment_color_correction = V.lut(preset, float(V.setting("strength")))
	else:
		graded_env.adjustment_color_correction = null


func _exit_tree() -> void:
	V.release()
