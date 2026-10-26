# Sound Indicators: your own footstep volume, by stance (what you hear only;
# enemies hear you the same).
extends "res://Scripts/Controller.gd"

const SI = preload("res://CSSoundIndicators/Mod.gd")


func PlayFootstep():
	var before := get_child_count()
	super()
	if not SI.active():
		return
	var key := "my_crouch" if gameData.isCrouching else ("my_run" if gameData.isRunning else "my_walk")
	var mult := float(SI.setting(key))
	if is_equal_approx(mult, 1.0):
		return
	for i in range(before, get_child_count()):
		var a = get_child(i)
		if a is AudioStreamPlayer:
			a.volume_db += linear_to_db(maxf(0.01, mult))
