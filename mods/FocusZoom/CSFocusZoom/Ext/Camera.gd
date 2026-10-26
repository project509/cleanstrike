# Focus Zoom: the camera heads for a narrower field of view while you focus,
# and a little narrower when aiming down iron sights or red dots.
extends "res://Scripts/Camera.gd"

const FZ = preload("res://CSFocusZoom/Mod.gd")

var fz_was_down := false


func FOV(delta):
	if not FZ.active():
		super(delta)
		return
	# Toggle mode: each press flips focus.
	var down := FZ.key_down()
	if bool(FZ.setting("toggle")) and down and not fz_was_down:
		FZ.toggled = not FZ.toggled
	fz_was_down = down
	# What the game wants (same conditions as its own FOV), then our zoom.
	var aiming: bool = gameData.isAiming and not gameData.isRunning and not gameData.isInspecting and not gameData.isColliding \
		and (gameData.weaponAction == "Manual" or not gameData.isReloading)
	var want: float = gameData.aimFOV if aiming else gameData.baseFOV
	var fov := FZ.target_fov(gameData, want, FZ.focusing(gameData))
	var speed := 50.0 if aiming else 25.0
	camera.fov = lerp(camera.fov, fov, delta * speed)
