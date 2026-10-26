# Self-test for Sound Indicators (cs_sound_indicators). r is the CSTest runner.
extends RefCounted

const SI = preload("res://CSSoundIndicators/Mod.gd")


func run(r) -> void:
	r.check("SoundIndicators: active", SI.active())
	var cam = r.get_viewport().get_camera_3d()
	var ahead: Vector3 = cam.global_position - cam.global_basis.z * 30.0
	var right: Vector3 = cam.global_position + cam.global_basis.x * 30.0
	r.check("SoundIndicators: close gunshots hidden", not SI.ping("shot", ahead, 5.0))
	r.check("SoundIndicators: gunshot shown", SI.ping("shot", ahead, 30.0))
	r.check("SoundIndicators: footstep shown", SI.ping("step", right, 30.0))
	r.check("SoundIndicators: far footsteps not shown", not SI.ping("step", right, 60.0))
	var o = SI.overlay()
	await r.wait(0.1)
	r.check("SoundIndicators: markers on screen", o.visible and o.marks.size() == 2)
	var shot_angle: float = o.angle_to(ahead)
	var step_angle: float = o.angle_to(right)
	r.check("SoundIndicators: markers point the right way", absf(shot_angle) < 0.05 and absf(step_angle - PI / 2.0) < 0.05, "%.2f / %.2f" % [shot_angle, step_angle])
	await r.wait(3.0)
	r.check("SoundIndicators: markers fade out", not o.visible)
	var hooked := 0
	for path in ["res://Scripts/AI.gd"]:
		var s = load(path)
		while s:
			if s.get_script_constant_map().has("SI"):
				hooked += 1
				break
			s = s.get_base_script()
	r.check("SoundIndicators: enemy sound hooks installed", hooked == 1)
