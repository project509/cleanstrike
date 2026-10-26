# Hideout Lights: a placed light fixture. Use switches it on and off.
extends Node3D

var gameData = preload("res://Resources/GameData.tres")
var lit := true
var label := "Light"


func _ready() -> void:
	if has_meta("cs_label"):
		label = str(get_meta("cs_label"))


func Interact() -> void:
	lit = not lit
	for l in find_children("*", "Light3D", true, false):
		l.visible = lit
	for p in find_children("*", "GPUParticles3D", true, false):
		p.emitting = lit
	UpdateTooltip()


func UpdateTooltip() -> void:
	gameData.tooltip = label + (" [Turn off]" if lit else " [Turn on]")
