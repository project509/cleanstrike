# Focus Zoom: while zoomed, mouse look slows down with the zoom (focal
# length), so the view moves the same on screen as without zoom.
extends "res://Scripts/Controller.gd"

const FZ = preload("res://CSFocusZoom/Mod.gd")


func _input(event):
	if not (event is InputEventMouseMotion) or not FZ.active() or not bool(FZ.setting("scale_sensitivity")):
		super(event)
		return
	var cam = get_viewport().get_camera_3d()
	if cam == null:
		super(event)
		return
	var want: float = gameData.aimFOV if gameData.isAiming else gameData.baseFOV
	var k := FZ.sensitivity_factor(cam.fov, want)
	if k >= 0.999 or k <= 0.0:
		super(event)
		return
	var look: float = gameData.lookSensitivity
	var aim: float = gameData.aimSensitivity
	var scope: float = gameData.scopeSensitivity
	gameData.lookSensitivity = look * k
	gameData.aimSensitivity = aim * k
	gameData.scopeSensitivity = scope * k
	super(event)
	gameData.lookSensitivity = look
	gameData.aimSensitivity = aim
	gameData.scopeSensitivity = scope
