# Self-test for Custom Fonts (cs_custom_fonts). r is the CSTest runner.
extends RefCounted

const CF = preload("res://CSCustomFonts/Mod.gd")


func run(r) -> void:
	r.check("CustomFonts: active", CF.active())
	var bad := []
	for n in CF.FONTS:
		var f: Font = CF.font_for(n)
		var want: String = "Lora" if n.begins_with("Lora") else n
		if f == null or not (want.replace(" ", "") in f.get_font_name().replace(" ", "")):
			bad.append("%s=%s" % [n, f.get_font_name() if f else "null"])
	r.check("CustomFonts: every font loads", bad.is_empty(), ", ".join(bad))
	var label: Label = r.get_node("/root/Map/Core/UI/Interface").find_children("*", "Label", true, false)[0]
	r.check("CustomFonts: game interface uses Play", label.get_theme_font("font").get_font_name() == "Play", label.get_theme_font("font").get_font_name())
	r.check("CustomFonts: fallback font for other panels", ThemeDB.fallback_font.get_font_name() == "Play")
	CF.overrides = {"font": "Lora (game)"}
	CF.apply()
	await r.wait(0.1)   # controls pick up theme changes on the next frame
	r.check("CustomFonts: back to the game font", label.get_theme_font("font").get_font_name() == load(CF.LORA).get_font_name(), label.get_theme_font("font").get_font_name() + " vs " + load(CF.LORA).get_font_name())
	CF.overrides = {}
	CF.apply()
