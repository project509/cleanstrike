# Self-test for Reticles (cs_reticles). r is the CSTest runner.
extends RefCounted

const R = preload("res://CSReticles/Mod.gd")


func run(r) -> void:
	r.check("Reticles: active", R.active())
	var sh := R.shader()
	r.check("Reticles: colour shader made from the game's", sh != null and "cs_tint" in sh.code)
	var m: ShaderMaterial = load(R.MATERIALS[0])
	var game_shader = load(R.GAME_SHADER)
	R.overrides = {"style": "Optic default", "color": "Red"}
	R.apply()
	r.check("Reticles: defaults leave the game's reticle alone", m.shader == game_shader)
	R.overrides = {"style": "Circle dot", "color": "Green"}
	R.apply()
	r.check("Reticles: green circle dot", m.shader == sh and m.get_shader_parameter("cs_tint") == R.COLORS.Green and m.get_shader_parameter("reticle") == R.texture("Circle dot"))
	r.check("Reticles: size and opacity kept", m.get_shader_parameter("size") != null and float(m.get_shader_parameter("intensity")) > 0.0)
	var bad := []
	for st in R.STYLES:
		if st != "Optic default":
			var img: Image = R.texture(st).get_image()
			if img.get_pixel(256, 256).a < 0.5 and not (st in ["Chevron", "Cross", "Triangle"]):
				bad.append(st + " no centre")
			if img.get_used_rect().size.x < 8:
				bad.append(st + " empty")
	r.check("Reticles: every shape draws", bad.is_empty(), ", ".join(bad))
	R.overrides = {}
	R.apply()
	r.check("Reticles: back to the game's reticle", m.shader == game_shader)
	R.overrides = {}
	R.apply()
