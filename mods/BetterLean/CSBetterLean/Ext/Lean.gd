# Better Lean: your lean angle, sideways distance and speed; sprinting ends
# a toggled lean.
extends "res://Scripts/Lean.gd"

const BL = preload("res://CSBetterLean/Mod.gd")


func _physics_process(delta):
	if BL.active():
		leanAngle = float(BL.setting("angle"))
		leanOffset = float(BL.setting("offset"))
		leanSpeed = float(BL.setting("speed"))
		if bool(BL.setting("sprint_cancels")) and gameData.isRunning:
			leanLToggle = false
			leanRToggle = false
	super(delta)
