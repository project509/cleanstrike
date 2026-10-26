# Tactical Watch: living enemies are counted for the panel.
extends "res://Scripts/AI.gd"

const TW = preload("res://CSTacticalWatch/Mod.gd")

var tw_counted := false


func _physics_process(delta: float) -> void:
	super(delta)
	if not tw_counted:
		tw_counted = true
		TW.ai.append(self)
