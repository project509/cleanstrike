# Sandbox Mode: the menu lives for the whole session.
extends Node

const SB = preload("res://CSSandboxMode/Mod.gd")


func _ready() -> void:
	if SB.active():
		var m = load("res://CSSandboxMode/Menu.gd").new()
		m.name = "Menu"
		add_child(m)
