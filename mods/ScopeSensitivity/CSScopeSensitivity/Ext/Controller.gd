# Scope Sensitivity: through a magnified scope, the mouse slows with the
# magnification (the game used one speed for every scope).
extends "res://Scripts/Controller.gd"

const SS = preload("res://CSScopeSensitivity/Mod.gd")

var ss_manager: Node


func _input(event):
	if not (event is InputEventMouseMotion) or not SS.active() or not (gameData.isAiming and gameData.isScoped):
		super(event)
		return
	var k := SS.factor(SS_ViewFov(), float(gameData.baseFOV))
	if k >= 0.999:
		super(event)
		return
	# Scale the movement itself: the game clamps sensitivity at 0.1, which
	# would cap the slow-down for players with low settings.
	var scaled: InputEventMouseMotion = event.duplicate()
	scaled.relative = event.relative * k
	super(scaled)


# What you see through the scope: its own camera (picture-in-picture
# scopes) or the narrowed main view.
func SS_ViewFov() -> float:
	if gameData.PIP:
		if ss_manager == null or not is_instance_valid(ss_manager):
			ss_manager = get_tree().current_scene.get_node_or_null("/root/Map/Core/Camera/Manager")
		if ss_manager:
			for rig in ss_manager.get_children():
				var optic = rig.get("activeOptic")
				if optic and is_instance_valid(optic) and optic.get("camera"):
					return float(optic.camera.fov)
	return float(gameData.aimFOV)
