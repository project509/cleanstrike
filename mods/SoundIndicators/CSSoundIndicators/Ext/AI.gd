# Sound Indicators: enemy gunshots and footsteps show as markers; enemy
# footsteps carry farther (normal up close, for honest distance reads).
extends "res://Scripts/AI.gd"

const SI = preload("res://CSSoundIndicators/Mod.gd")

var si_next_step := 0.0


func PlayFire():
	super()
	if SI.active():
		SI.ping("shot", global_position, playerDistance)


func PlayFootstep():
	if not SI.active():
		super()
		return
	var range_mult := maxf(1.0, float(SI.setting("ai_step_range")))
	var far: bool = playerDistance > 50.0 and playerDistance <= 50.0 * range_mult
	var real: float = playerDistance
	if far:
		playerDistance = 49.9   # the game skips steps past 50 m
	var before := get_child_count()
	super()
	playerDistance = real
	if real > float(SI.setting("close_reset")):
		for i in range(before, get_child_count()):
			var a = get_child(i)
			if a is AudioStreamPlayer3D:
				a.max_distance = 50.0 * range_mult
				a.unit_size = 10.0 * range_mult
	# Markers: not while they can see you; farther steps update less often
	var now := Time.get_ticks_msec() / 1000.0
	if not sensor.PVisible and now >= si_next_step:
		if SI.ping("step", global_position, real):
			si_next_step = now + lerpf(0.25, 1.5, clampf(real / maxf(1.0, float(SI.setting("step_max"))), 0.0, 1.0))
