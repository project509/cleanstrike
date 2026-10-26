# Tactical Watch: the wrist panel lives on the HUD.
extends "res://Scripts/HUD.gd"

const TW = preload("res://CSTacticalWatch/Mod.gd")


func _ready():
	super()
	if TW.active():
		TW.apply_loot()
		var p = load("res://CSTacticalWatch/Panel.gd").new()
		p.name = "CS_Watch"
		add_child(p)
